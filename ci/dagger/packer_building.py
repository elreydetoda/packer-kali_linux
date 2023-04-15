import click

from dagger import Client

from models.config import ConfigObj


async def virtualbox_build(
    client: Client,
    conf: ConfigObj,
    version: str,
    build_results: list,
) -> None:
    """
    Build a virtualbox image
    """
    click.echo(f"Building virtualbox image for version {version}")


async def vmware_build(
    client: Client,
    conf: ConfigObj,
    version: str,
    build_results: list,
) -> None:
    """
    Build a vmware image
    """
    click.echo(f"Building vmware image for version {version}")


async def qemu_build(
    client: Client,
    conf: ConfigObj,
    version: str,
    build_results: list,
) -> None:
    """
    Build a qemu image
    """
    click.echo(f"Building qemu image for version {version}")
