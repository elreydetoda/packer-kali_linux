#!/usr/bin/env python3

from os import getenv
from pathlib import Path
from sys import exit as s_exit

import anyio, click  # pylint: disable=multiple-imports
from click.core import Context as click_Context
from yaml import safe_load as y_safe_load


import linting
from async_interface import (
    main_builder,
    main_deploy,
    main_lint,
    main_destroy,
    main_provision,
)
from models.linting import LintReturnObj, LintSubDict
from models.config import ConfigObj


@click.group()
@click.pass_context
def main(
    ctx: click_Context,
):
    """
    Main entry point for CI/CD automation
    """
    ctx.ensure_object(dict)
    base_path = Path(__file__).resolve()
    git_root = base_path.parent.parent.parent
    config_data = y_safe_load(Path(base_path.parent / "config.yml").read_text("utf-8"))
    ctx.obj["CONFIG"] = ConfigObj(
        base_path,
        git_root,
        config_data,
        Path(git_root / ".linting-configs").relative_to(git_root),
    )


# @main.command()
# @click.pass_obj
# def check(ctx_obj: dict):
#     click.echo(ctx_obj)


# ELREY_PKR_LINT_PYTHON=true
@main.command("lint")
@click.pass_obj
# @click.pass_context
@click.option(
    "-a",
    "--ansible",
    is_flag=True,
    help="Lint the ansible files",
)
@click.option(
    "-p",
    "--python",
    is_flag=True,
    help="Lint python files",
)
@click.option(
    "-t",
    "--terraform",
    is_flag=True,
    help="Lint terraform files",
)
@click.option(
    "-b",
    "--packer",
    is_flag=True,
    help="Lint packer files",
)
@click.option(
    "-s",
    "--shell",
    is_flag=True,
    help="Lint shell files",
)
@click.option(
    "--all",
    "all_lints",
    is_flag=True,
    help="Lint all files with all linters",
)
def lint(
    ctx_obj: dict,
    # ctx: click_Context,
    ansible: bool,
    python: bool,
    terraform: bool,
    packer: bool,
    shell: bool,
    all_lints: bool,
):  # pylint: disable=too-many-arguments
    """
    Lints files based on the parameters passed in
    """

    lint_dict = {}

    conf: ConfigObj = ctx_obj["CONFIG"]
    # conf: ConfigObj = ctx.obj["CONFIG"]
    # print(ctx.params)

    if ansible or all_lints:
        linting.prep_lint("ansible", conf, lint_dict)
    if python or all_lints:
        linting.prep_lint("python", conf, lint_dict)
    if terraform or all_lints:
        linting.prep_lint("terraform", conf, lint_dict)
    if packer or all_lints:
        linting.prep_lint("packer", conf, lint_dict)
    if shell or all_lints:
        linting.prep_lint("shell", conf, lint_dict)

    resultz = anyio.run(main_lint, conf, lint_dict)
    # for func_str, lint_dict_vals in lint_dict.items():
    #     lint_dict_vals: LintSubDict
    #     func_to_run = getattr(linting, f"{func_str}_lint")
    #     lint_dict_vals.results.extend(func_to_run(conf, lint_dict_vals.files))

    failed = False

    for tool_name, tool_data in resultz.items():
        tool_data: LintSubDict
        results = tool_data.results

        click.echo(f"tool: {tool_name}")

        for result in results:
            result: LintReturnObj
            click.echo(f"sub-tool: {result.tool_name}")
            click.echo(f"version: {result.tool_version}")
            if result.cwd:
                click.echo(f"cwd: {result.cwd}")
            click.echo(f"return code: {result.return_code}")
            click.echo(f"stdout: {result.return_stdout}")
            click.echo(f"stderr: {result.return_stderr}")
            if result.return_code != 0:
                failed = True

    if getenv("IGNORE_LINTING_ERRORS"):
        s_exit(0)
    if failed:
        raise click.ClickException("Linting failed")


@main.command("deploy")
@click.pass_obj
@click.confirmation_option(prompt="Are you sure you want to deploy/destroy?")
@click.option(
    "-d",
    "--destroy",
    is_flag=True,
    help="Destroy the servers instead of deploying them",
)
def deploy(
    ctx_obj: dict,
    destroy: bool,
):
    """
    Deploys the servers for the builds to run on
    """
    conf: ConfigObj = ctx_obj["CONFIG"]

    if destroy:
        terraform_version, terraform_deployed_results = anyio.run(main_destroy, conf)
    else:
        terraform_version, terraform_deployed_results = anyio.run(main_deploy, conf)

    click.echo(f"Terraform Version: {terraform_version}")
    click.echo(f"Return Code: {terraform_deployed_results.exit_code}")
    click.echo(f"Output: {terraform_deployed_results.stdout}")
    click.echo(f"Error: {terraform_deployed_results.stderr}")


@main.command("build")
@click.pass_obj
@click.option(
    "-p/-np",
    "--provision/--no-provision",
    is_flag=True,
    help="Provision the servers before building (default: True)",
    default=True,
)
@click.option(
    "-vb",
    "--virtualbox",
    is_flag=True,
    help="Build the virtualbox images",
)
@click.option(
    "-vm",
    "--vmware",
    is_flag=True,
    help="Build the vmware images",
)
@click.option(
    "-q",
    "--qemu",
    is_flag=True,
    help="Build the qemu images",
)
@click.option(
    "--all",
    "all_builders",
    is_flag=True,
    help="Build all images with all builders",
)
def build(
    ctx_obj: dict,
    provision: bool,
    virtualbox: bool,
    vmware: bool,
    qemu: bool,
    all_builders: bool,
):
    """
    Provisions the servers for the builds to run on
    """
    conf: ConfigObj = ctx_obj["CONFIG"]
    builder_list = []

    if provision:
        click.echo(f"Provisioning servers: {provision}")
        anyio.run(main_provision, conf)

    if virtualbox or all_builders:
        builder_list.append("virtualbox")
    if vmware or all_builders:
        builder_list.append("vmware")
    if qemu or all_builders:
        builder_list.append("qemu")
    click.echo("Building on build servers")
    anyio.run(main_builder, conf, builder_list)


if __name__ == "__main__":
    # pylint: disable=no-value-for-parameter
    main(auto_envvar_prefix="ELREY_PKR")
