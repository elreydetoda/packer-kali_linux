#!/usr/bin/env python3

from pathlib import Path
from subprocess import run as s_run, PIPE
from typing import List, Set

import anyio, dagger, click
from click.core import Context as click_Context
from yaml import safe_load as y_safe_load

from models.linting import LintReturnObj
from models.config import ConfigObj

import linting


@click.group()
@click.pass_context
def main(
    ctx: click_Context,
):
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


@main.command()
@click.pass_obj
def check(ctx_obj: dict):
    click.echo(ctx_obj)


@main.command("lint")
@click.pass_obj
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
def lint(
    ctx_obj: dict,
    ansible: bool,
    python: bool,
    terraform: bool,
    packer: bool,
    shell: bool,
):
    """
    Lints files based on the parameters passed in
    """

    lint_dict = {}

    conf: ConfigObj = ctx_obj["CONFIG"]

    if ansible:
        linting.prep_lint("ansible", conf, lint_dict)
    if python:
        linting.prep_lint("python", conf, lint_dict)
    if terraform:
        linting.prep_lint("terraform", conf, lint_dict)
    if packer:
        linting.prep_lint("packer", conf, lint_dict)
    if shell:
        linting.prep_lint("shell", conf, lint_dict)

    for func_str, lint_dict_vals in lint_dict.items():
        func_to_run = getattr(linting, f"{func_str}_lint")
        lint_dict_vals["results"].extend(func_to_run(conf, lint_dict_vals["files"]))

    for tool_name, tool_data in lint_dict.items():
        results: List[LintReturnObj] = tool_data["results"]

        click.echo(f"tool: {tool_name}")

        for result in results:
            click.echo(f"sub-tool: {result.tool_name}")
            click.echo(f"version: {result.tool_version}")
            click.echo(result.return_code)
            click.echo(result.return_stdout)
            click.echo(result.return_stderr)


# async def cli():
#     cfg = dagger.Config(log_output=sys.stderr)

#     async with dagger.Connection(cfg) as client:
#         ctr = client.container().from_("python:3.9")
# ctr.


if __name__ == "__main__":
    # pylint: disable=no-value-for-parameter
    main()
