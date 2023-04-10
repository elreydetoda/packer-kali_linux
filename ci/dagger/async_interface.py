import sys
from copy import deepcopy

import dagger, anyio  # pylint: disable=multiple-imports

import linting
from models.config import ConfigObj
from models.linting import LintSubDict


async def main_lint(conf: ConfigObj, lint_dict: dict) -> dict:
    """
    Thin async wrapper around the main linting function
    """

    new_lint_dict = deepcopy(lint_dict)
    async with dagger.Connection(
        dagger.Config(
            workdir=conf.git_root,
            log_output=sys.stderr,
        )
    ) as client:
        async with anyio.create_task_group() as task_group:
            for func_str, lint_dict_vals in new_lint_dict.items():
                lint_dict_vals: LintSubDict
                func_to_run = getattr(linting, f"{func_str}_lint")
                task_group.start_soon(func_to_run, client, conf, lint_dict_vals)
    return new_lint_dict
