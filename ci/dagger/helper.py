import re
from os import getenv
from pathlib import Path
from json import dumps as j_dumps

import click  # pylint: disable=unused-import

from dagger import Client, Container
from dagger.exceptions import QueryError
from anyio import Path as AsyncPath

from models.config import ConfigObj
from models.misc import DaggerExecResult


def find(conf: ConfigObj, pattern: str):
    """
    Finds files based on the given pattern
    """
    paths = set(Path(conf.git_root).glob(f"**/{pattern}"))
    result = {
        # return the sanitized path
        path.resolve().relative_to(conf.git_root)
        # loop through all the results
        for path in paths
        # ensure they're not returning bento files or from .git/
        if ".git" not in str(path) and "bento" not in str(path)
    }
    return result


def dagger_general_prep(
    client: Client,
    conf: ConfigObj,
    container_img: str,
) -> Container:
    """
    Prepares the client with the provided container image (str)
    then returns the container object after mounting to the git root
    and setting the working directory to that folder
    """
    return (
        # setting the container image to return
        client.container().from_(conf.config_data["container_images"][container_img])
        # mount root of git repo
        .with_mounted_directory("/src", client.host().directory("."))
        # set CWD in container
        .with_workdir("/src")
    )


async def dagger_python_prep(
    client: Client,
    conf: ConfigObj,
    container: Container,
    prod: bool = False,
    system: bool = False,
) -> Container:
    """
    prepare container for python specific needs (i.e. install pipenv, deps, etc.)
    """
    pipenv_cmd = "pipenv sync"
    if not prod:
        pipenv_cmd += " --dev"
    if system:
        pipenv_cmd += " --system"
    return (
        container
        # system python level deps
        .with_mounted_cache(
            "/root/.local",
            client.cache_volume("system_python"),
        )
        # adding a project cache for .venv
        .with_mounted_cache(
            "/src/.venv",
            client.cache_volume("project_python"),
        )
        # installing pipenv for deps
        .with_exec(
            f"pip3 install --user pipenv=={conf.config_data['pipenv_version']}".split()
        )
        # expanding path to include local install of pipenv
        .with_env_variable(
            "PATH", f"/root/.local/bin:{await container.env_variable('PATH')}"
        )
        # .with_env_variable("PATH", "/root/.local/bin:$PATH")
        # setting pipenv to use the project's venv (i.e. .venv/)
        .with_env_variable("PIPENV_VENV_IN_PROJECT", "1")
        # installing deps
        .with_exec(pipenv_cmd.split())
    )


def dagger_ansible_prep(
    client: Client,
    container: Container,
) -> Container:
    """
    prepare container for ansible specific needs (i.e. install collections, roles, etc.)
    """
    pipenv_cmd = "pipenv run"
    return (
        container
        # adding a project cache for roles
        .with_mounted_cache(
            "/root/.ansible/roles",
            client.cache_volume("project_ansible_roles"),
        )
        # adding a project cache for collections
        .with_mounted_cache(
            "/root/.ansible/collections",
            client.cache_volume("project_ansible_collections"),
        )
        # installing collections
        .with_exec(
            f"{pipenv_cmd} ansible-galaxy collection install -r ci/ansible/requirements.yml".split()
        )
        # installing roles
        .with_exec(
            f"{pipenv_cmd} ansible-galaxy role install -r ci/ansible/requirements.yml".split()
        )
    )


async def dagger_terraform_prep(
    client: Client,
    container: Container,
) -> Container:
    """
    prepare container for terraform specific needs
    (i.e. install providers, initialize backends, etc.)
    """

    terraform_login_dict = {
        "credentials": {
            "app.terraform.io": {
                "token": "",
            },
        },
    }

    prepped_container = None
    credentials_file = AsyncPath("/root/.terraform.d/credentials.tfrc.json")
    tf_login = client.set_secret("tf_cloud_login", getenv("TFC_AUTH_TOKEN", ""))
    tf_plaintext = await tf_login.plaintext()

    # require login token for terraform cloud
    #   if in CI, raise an exception if empty
    if getenv("CI"):
        # if an empty string, or a falsy value, raise an exception
        if not tf_plaintext:
            raise click.ClickException(
                "Terraform Cloud login token not found in secrets"
            )

    if tf_plaintext:
        terraform_login_dict["credentials"]["app.terraform.io"]["token"] = tf_plaintext
        tf_login_file = client.set_secret(
            "tf_login_file",
            j_dumps(
                terraform_login_dict,
                indent=4,
                ensure_ascii=True,
            ),
        )
        prepped_container = (
            container
            # create file for terraform login
            .with_mounted_secret(str(credentials_file), tf_login_file)
        )

    return prepped_container or container


def dagger_terraform_deployment_prep(
    client: Client,
    container: Container,
    folder: str,
) -> Container:
    """
    prepare container for terraform deployment specific needs
    (i.e. install providers, initialize backends, etc.)
    """
    return (
        container
        # setting CWD to deployment folder
        .with_workdir(f"/src/{folder}")
        # caching providers
        .with_mounted_cache(
            f"/src/{folder}/.terraform",
            client.cache_volume("project_terraform_providers"),
        )
        # initializing terraform in that folder
        .with_exec("init".split())
    )


##################################################
# TEMPORARY


async def dagger_handle_query_error(
    container: Container, handle_error=True
) -> DaggerExecResult:
    """
    handle dagger query errors, and return all relevant data based on error or not
    """
    if handle_error:
        try:
            return DaggerExecResult(
                await container.stdout(),
                await container.stderr(),
                await container.exit_code(),
            )
        except QueryError as query_err:
            # FIXME: hack till there's an official process, based off of
            msg = str(query_err)
            # https://github.com/dagger/dagger/issues/4706#issuecomment-1499371201
            if "exit code:" not in msg:
                # this could be a network error for example
                raise

            # pylint: disable=line-too-long
            matched_dict = re.search(
                r"(?P<error_msg>.*?)(?:exit\s+code:\s+)(?P<exit_code>\d+).(?:Stdout:)(?P<stdout>.*?)(?:Stderr:)(?P<stderr>.*?)(?:CUSTOM_EOF)",
                msg + "CUSTOM_EOF",
                re.MULTILINE | re.DOTALL,
            ).groupdict()

            # TODO: add more error handling here
            #   i.e. expected errors for specific tools
            #   based on the error_msg extrated text
            return DaggerExecResult(
                matched_dict.get("stdout").strip(),
                matched_dict.get("stderr").strip(),
                matched_dict.get("exit_code"),
                matched_dict.get("error_msg").strip(),
                # _raw=msg,
            )

    # if we don't handle errors, just return the data
    return DaggerExecResult(
        await container.stdout(),
        await container.stderr(),
        await container.exit_code(),
    )


##################################################
