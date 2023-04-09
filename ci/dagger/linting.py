from pathlib import Path
from typing import List

import click
from dagger import Client

from helper import (
    dagger_ansible_prep,
    dagger_handle_query_error,
    find,
    dagger_general_prep,
    dagger_python_prep,
)
from models.config import ConfigObj
from models.linting import LintReturnObj, LintSubDict


def prep_lint(
    base_key: str,
    conf: ConfigObj,
    return_dict: dict,
) -> None:
    """
    Prepares the linting process by finding all the files to lint,
    and also setting some default values
    """

    return_dict.setdefault(base_key, {})
    return_dict[base_key] = LintSubDict()

    for pattern in conf.config_data[base_key]["patterns"]:
        return_dict[base_key].files.update(find(conf, pattern=pattern))


async def ansible_lint(
    client: Client,
    conf: ConfigObj,
    lint_sub_dict: LintSubDict,
):
    """
    Runs ansible-lint on the given files
    """

    ansible_base = dagger_general_prep(client, conf, "python")
    python_prepped = await dagger_python_prep(client, conf, ansible_base)
    ansible_prepped = dagger_ansible_prep(client, python_prepped)

    cmd_prep = "pipenv run "

    ansible_lint_result = await dagger_handle_query_error(
        ansible_prepped.with_exec(
            str(
                cmd_prep
                + "ansible-lint"
                # configuration files
                + f" -c {Path(conf.lintrc_dir/'ansible-lint')}"
            ).split()
            + [str(file) for file in lint_sub_dict.files],
        )
    )
    ansible_lint_version = await dagger_handle_query_error(
        ansible_prepped.with_exec(
            f"{cmd_prep} ansible-lint --version --nocolor".split(),
        )
    )

    lint_sub_dict.results.append(
        LintReturnObj(
            "ansible-lint",
            ansible_lint_version.stdout.split()[1],
            ansible_lint_version.stdout,
            ansible_lint_result.exit_code,
            ansible_lint_result.stdout,
            ansible_lint_result.stderr,
        )
    )


async def python_lint(
    client: Client,
    conf: ConfigObj,
    lint_sub_dict: LintSubDict,
):
    """
    Runs pylint and black on the given files
    """

    exclude_set = {
        # from old project, and will eventually be removed
        "packer_w_mfa.py",
        "template_gen.py",
    }
    file_strs = [
        str(file) for file in lint_sub_dict.files if file.name not in exclude_set
    ]

    base_prep = dagger_general_prep(client, conf, "python")
    python_prepped = await dagger_python_prep(client, conf, base_prep)

    cmd_prep = "pipenv run "

    pylint_results = await dagger_handle_query_error(
        (
            python_prepped
            # run pylint
            .with_exec(
                str(
                    cmd_prep
                    # actual command
                    + "pylint"
                    # configuration files
                    + f" --rcfile {Path(conf.lintrc_dir/'pylintrc')}"
                ).split()
                + file_strs,
            )
        )
    )

    pylint_version_results = await dagger_handle_query_error(
        python_prepped.with_exec(
            str(cmd_prep + "pylint --version").split(),
        )
    )

    lint_sub_dict.results.append(
        LintReturnObj(
            "pylint",
            pylint_version_results.stdout.split()[1],
            pylint_version_results.stdout,
            pylint_results.exit_code,
            pylint_results.stdout,
            pylint_results.stderr,
        )
    )

    black_results = await dagger_handle_query_error(
        (
            python_prepped
            # run black
            .with_exec(
                str(
                    cmd_prep
                    # actual command
                    + "black"
                    # parameters
                    + " --check --diff --color"
                ).split()
                + file_strs,
            )
        )
    )

    black_version = await dagger_handle_query_error(
        python_prepped.with_exec(
            str(cmd_prep + "black --version").split(),
        )
    )

    lint_sub_dict.results.append(
        LintReturnObj(
            "black",
            black_version.stdout.split()[1],
            black_version.stdout,
            black_results.exit_code,
            black_results.stdout,
            black_results.stderr,
        )
    )


async def terraform_lint(
    client: Client,
    conf: ConfigObj,
    lint_sub_dict: LintSubDict,
) -> List[LintReturnObj]:
    """
    Runs terraform fmt on the given files
    """

    folders = list({str(file.parent) for file in lint_sub_dict.files})

    terraform_prep = dagger_general_prep(client, conf, "terraform")

    terraform_version = await dagger_handle_query_error(
        terraform_prep.with_exec(
            "-version".split(),
        )
    )

    for folder in folders:
        relative_terraform = terraform_prep.with_workdir(f"/src/{folder}")

        await relative_terraform.with_exec("init".split()).exit_code()

        terraform_fmt_results = await dagger_handle_query_error(
            relative_terraform.with_exec(
                "fmt -check -diff".split(),
            )
        )

        lint_sub_dict.results.append(
            LintReturnObj(
                "terraform-fmt",
                terraform_version.stdout.split()[1],
                terraform_version.stdout,
                terraform_fmt_results.exit_code,
                terraform_fmt_results.stdout,
                terraform_fmt_results.stderr,
            )
        )
        terraform_validate_results = await dagger_handle_query_error(
            relative_terraform.with_exec(
                "validate".split(),
            )
        )

        lint_sub_dict.results.append(
            LintReturnObj(
                "terraform-validate",
                terraform_version.stdout.split()[1],
                terraform_version.stdout,
                terraform_validate_results.exit_code,
                terraform_validate_results.stdout,
                terraform_validate_results.stderr,
            )
        )


async def packer_lint(
    client: Client,
    conf: ConfigObj,
    lint_sub_dict: LintSubDict,
):
    """
    Runs packer fmt on the given files
    """

    folders = list({str(file.parent) for file in lint_sub_dict.files})

    packer_prep = dagger_general_prep(client, conf, "packer")

    packer_version = await dagger_handle_query_error(
        packer_prep.with_exec(
            "-version".split(),
        )
    )

    for folder in folders:
        relative_packer = packer_prep.with_workdir(f"/src/{folder}")

        await relative_packer.with_exec("init .".split()).exit_code()

        packer_fmt_results = await dagger_handle_query_error(
            relative_packer.with_exec(
                "fmt -check -diff .".split(),
            )
        )

        lint_sub_dict.results.append(
            LintReturnObj(
                "packer-fmt",
                packer_version.stdout,
                packer_version.stdout,
                packer_fmt_results.exit_code,
                packer_fmt_results.stdout,
                packer_fmt_results.stderr,
                folder,
            )
        )
        packer_validate_results = await dagger_handle_query_error(
            relative_packer.with_exec(
                "validate .".split(),
            )
        )

        lint_sub_dict.results.append(
            LintReturnObj(
                "packer-validate",
                packer_version.stdout,
                packer_version.stdout,
                packer_validate_results.exit_code,
                packer_validate_results.stdout,
                packer_validate_results.stderr,
                folder,
            )
        )


async def shell_lint(
    client: Client,
    conf: ConfigObj,
    lint_sub_dict: LintSubDict,
) -> List[LintReturnObj]:
    """
    Runs shell linting (shellcheck & shfmt) on the given files
    """

    file_strs = [str(file) for file in lint_sub_dict.files]

    sh_check_prep = dagger_general_prep(client, conf, "shellcheck")

    shellcheck_results = await dagger_handle_query_error(
        sh_check_prep.with_exec(
            "-S warning".split() + file_strs,
        )
    )
    shellcheck_version = await dagger_handle_query_error(
        sh_check_prep.with_exec("--version".split())
    )

    lint_sub_dict.results.append(
        LintReturnObj(
            "shellcheck",
            shellcheck_version.stdout.split("\n")[1].split()[1],
            shellcheck_version.stdout,
            shellcheck_results.exit_code,
            shellcheck_results.stdout,
            shellcheck_results.stderr,
        )
    )

    sh_fmt_prep = dagger_general_prep(client, conf, "shfmt")

    shfmt_results = await dagger_handle_query_error(
        sh_fmt_prep.with_exec(
            "-i 2 -ci -sr -l -d".split() + file_strs,
        )
    )
    shfmt_version = await dagger_handle_query_error(
        sh_fmt_prep.with_exec("--version".split())
    )

    lint_sub_dict.results.append(
        LintReturnObj(
            "shfmt",
            shfmt_version.stdout,
            shfmt_version.stdout,
            shfmt_results.exit_code,
            shfmt_results.stdout,
            shfmt_results.stderr,
        ),
    )
