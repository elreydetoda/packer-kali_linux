#!/usr/bin/env python3

from pathlib import Path
from subprocess import run as s_run, PIPE
from typing import List, Set

import anyio, click
from click.core import Context as click_Context
from yaml import safe_load as y_safe_load


import linting
from async_interface import main_lint
from models.linting import LintReturnObj, LintSubDict
from models.config import ConfigObj


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
):
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

    for tool_name, tool_data in resultz.items():
        tool_data: LintSubDict
        results = tool_data.results

        click.echo(f"tool: {tool_name}")

        for result in results:
            click.echo(f"sub-tool: {result.tool_name}")
            click.echo(f"version: {result.tool_version}")
            if result.cwd:
                click.echo(f"cwd: {result.cwd}")
            click.echo(f"return code: {result.return_code}")
            click.echo(f"stdout: {result.return_stdout}")
            click.echo(f"stderr: {result.return_stderr}")


# async def cli():
#     cfg = dagger.Config(log_output=sys.stderr)

#     async with dagger.Connection(cfg) as client:
#         ctr = client.container().from_("python:3.9")
# ctr.


if __name__ == "__main__":
    # pylint: disable=no-value-for-parameter
    main(auto_envvar_prefix="ELREY_PKR")
