from pathlib import Path

from dagger.api.gen import Container, Client

from models.config import ConfigObj


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
    conf: ConfigObj,
    container: Container,
    prod: bool = False,
) -> Container:
    return (
        container
        # installing pipenv for deps
        .with_exec(f"pip3 install pipenv=={conf.config_data['pipenv_version']}".split())
        # installing deps
        .with_exec(
            # return if prod environment, don't install dev deps
            "pipenv sync".split()
            if prod
            # return if dev environment (Default: prod=False)
            else "pipenv sync -d".split()
        )
    )
