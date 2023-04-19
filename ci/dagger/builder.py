#!/usr/bin/env python3

from sys import stderr
from typing import List, Literal, Tuple
import click
from click import Context as click_Context
from loguru import logger

from models.misc import SemanticVersion
from models.builder import BuildPrepMeta, BuildTaskMeta, KaliIsoMeta


@click.group()
@click.option(
    "-d",
    "--debug",
    is_flag=True,
    help="Enable debug logging",
)
@click.option(
    "-t",
    "--trace",
    is_flag=True,
    help="Enable trace logging",
)
@click.option(
    "-vr",
    "--vm_version",
    type=SemanticVersion,
    help="The version of the VM to build",
)
@click.argument(
    "build_version",
    type=click.Choice(
        [
            "default",
            "light",
            "min",
        ],
        case_sensitive=False,
    ),
)
@click.option(
    "-p",
    "--providers",
    type=click.Choice(
        [
            "virtualbox",
            "vmware",
            "qemu",
        ],
        case_sensitive=False,
    ),
    multiple=True,
    required=True,
)
@click.option(
    "-u",
    "--vagrant_cloud_user",
    type=str,
    help="The vagrant cloud user to upload to",
    default="elrey741",
)
@click.pass_context
@logger.catch(reraise=True)
def main(
    ctx: click_Context,
    debug: bool,
    trace: bool,
    vm_version: SemanticVersion,
    build_version: Literal["default", "light", "min"],
    providers: Tuple[Literal["virtualbox", "vmware", "qemu"], ...],
    vagrant_cloud_user: str,
):
    """
    Main entry point for the build automation system (packer)

    """
    ##############################
    # Setup logging
    logger.remove(0)
    logger.add(
        stderr,
        level=("TRACE" if trace else "DEBUG" if debug else "INFO"),
    )
    # pylint: disable=line-too-long
    # logger.add(
    #     "build.log",
    #     level="TRACE",
    #     format="<green>{time:YYYY-MM-DD HH:mm:ss.SSS!UTC}</green> | <level>{level: <8}</level> | <cyan>{name}</cyan>:<cyan>{function}</cyan>:<cyan>{line}</cyan> - <level>{message}</level>",
    # )
    ##############################

    ctx.ensure_object(dict)
    ctx.obj["BUILD_INFO"] = BuildPrepMeta(
        vagrant_cloud_user=vagrant_cloud_user,
        build_version=build_version,
        providers=providers,
    )
    ctx.obj["KALI_INFO"] = KaliIsoMeta()
    ctx.obj["BUILD_QUEUE"] = []
    for provider in providers:
        ctx.obj["BUILD_QUEUE"].append(
            BuildTaskMeta(
                metadata=ctx.obj["BUILD_INFO"],
                provider=provider,
                vm_version=vm_version,
            )
        )
    # pylint: disable=pointless-string-statement
    """
    Build 'qemu.vm' finished after 31 minutes 18 seconds.

    ==> Wait completed after 31 minutes 18 seconds

    ==> Builds finished. The artifacts of successful builds are:
    --> qemu.vm: 'libvirt' provider box: ./builds/red-automated_kali.libvirt-min.box
    """
    # build_version
    # vm_version
    # # kali-min-linux_amd64-dev
    # # vm_name
    # providers
    # iso_checksum
    # iso_url

    # box_basename = "red-automated_kali"


@main.command()
@click.pass_obj
@logger.catch(reraise=True)
def build(
    ctx_obj: dict,
):
    """
    wrapper for packer's build of images
    """
    # click.echo("Building images")
    # logger.info("INFOZ")
    build_info: BuildPrepMeta = ctx_obj["BUILD_INFO"]
    build_tasks: List[BuildTaskMeta] = ctx_obj["BUILD_QUEUE"]
    kali_info: KaliIsoMeta = ctx_obj["KALI_INFO"]
    logger.debug(f"Initially passed info: {build_info}")
    logger.debug(f"Build tasks: {build_tasks}")
    logger.debug(f"Kali info: {kali_info}")
    # if not build_info.vm_version:
    #     build_info.vm_version = SemanticVersion("0.0.0")
    # logger.critical("CRITICALZ")
    # 12 / 0


if __name__ == "__main__":
    # pylint: disable=no-value-for-parameter
    main(auto_envvar_prefix="ELREY_PKR_BLD")
