#!/usr/bin/env python3

from pathlib import Path
from subprocess import run as s_run, PIPE
from typing import List, Set

import anyio, dagger, click
from click.core import Context as click_Context
from yaml import safe_load as y_safe_load

from models.helper import LintReturnObj
from models.config import ConfigObj

import helper


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
        Path(git_root / ".linting-configs"),
    )


@main.command()
@click.pass_obj
def check(ctx_obj: dict):
    click.echo(ctx_obj)


@main.command("find")
@click.argument("pattern")
@click.pass_context
def find(ctx: click_Context, pattern: str):
    conf: ConfigObj = ctx.obj["CONFIG"]
    paths = set(Path(conf.git_root).glob(f"**/{pattern}"))
    result = {
        # return the sanitized path
        path
        # loop through all the results
        for path in paths
        # ensure they're not returning bento files or from .git/
        if ".git" not in str(path) and "bento" not in str(path)
    }
    return result
    # result = s_run(
    #     f'find "{conf.git_root}" -iname "{pattern}"'.split(),
    #     check=True,
    #     stdout=PIPE,
    #     stderr=PIPE,
    #     shell=True,
    # )
    # click.echo((result.stdout.decode(), result.stderr.decode()))


@main.command("lint")
@click.pass_context
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
    ctx: click_Context,
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

    conf: ConfigObj = ctx.obj["CONFIG"]

    if ansible:
        helper.prep_lint("ansible", ctx, lint_dict)
    if python:
        helper.prep_lint("python", ctx, lint_dict)
    if terraform:
        helper.prep_lint("terraform", ctx, lint_dict)
    if packer:
        helper.prep_lint("packer", ctx, lint_dict)
    if shell:
        helper.prep_lint("shell", ctx, lint_dict)

    for func_str, lint_dict_vals in lint_dict.items():
        func_to_run = getattr(helper, f"{func_str}_lint")
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


if __name__ == "__main__":
    # pylint: disable=no-value-for-parameter
    main()
