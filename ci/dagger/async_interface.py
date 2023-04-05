import sys
from copy import deepcopy

import dagger, anyio

import linting
from models.config import ConfigObj
from models.linting import LintSubDict


async def main_lint(conf: ConfigObj, lint_dict: dict) -> dict:
    new_lint_dict = deepcopy(lint_dict)
    async with dagger.Connection(
        dagger.Config(
            workdir=conf.git_root,
            log_output=sys.stderr,
        )
    ) as client:
        async with anyio.create_task_group() as tg:
            for func_str, lint_dict_vals in new_lint_dict.items():
                lint_dict_vals: LintSubDict
                func_to_run = getattr(linting, f"{func_str}_lint")
                tg.start_soon(func_to_run, client, conf, lint_dict_vals)
    return new_lint_dict
