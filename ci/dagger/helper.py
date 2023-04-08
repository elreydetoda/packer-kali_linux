import re
from pathlib import Path

import click  # pylint: disable=unused-import

from dagger import Client, Container
from dagger.exceptions import QueryError

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


def dagger_python_prep(
    client: Client,
    conf: ConfigObj,
    container: Container,
    prod: bool = False,
) -> Container:
    """
    prepare container for python specific needs (i.e. install pipenv, deps, etc.)
    """
    return (
        container
        # system level deps
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
        .with_env_variable("PATH", "/root/.local/bin:$PATH")
        # setting pipenv to use the project's venv (i.e. .venv/)
        .with_env_variable("PIPENV_VENV_IN_PROJECT", "1")
        # installing deps
        .with_exec(
            # return if prod environment, don't install dev deps
            "pipenv sync".split()
            if prod
            # return if dev environment (Default: prod=False)
            else "pipenv sync -d".split()
        )
    )


async def dagger_handle_query_error(container: Container) -> DaggerExecResult:
    """
    handle dagger query errors, and return all relevant data based on error or not
    """
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
        )
