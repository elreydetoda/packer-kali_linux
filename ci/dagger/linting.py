from pathlib import Path
from subprocess import run as s_run, PIPE
from typing import List, Set

import click
from dagger.api.gen import Client
from dagger.exceptions import QueryError

from helper import find, dagger_general_prep, dagger_python_prep
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


def ansible_lint(
    client: Client,
    conf: ConfigObj,
    files: Set[Path],
) -> List[LintReturnObj]:
    """
    Runs ansible-lint on the given files
    """
    return_list = []

    cmd_prep = "pipenv run "
    lint_result = s_run(
        str(
            cmd_prep
            # actual command
            + "ansible-lint"
            # configuration files
            + f" -c {Path(conf.lintrc_dir/'ansible-lint')}"
        ).split()
        + [str(file) for file in files],
        cwd=conf.git_root,
        stdout=PIPE,
        stderr=PIPE,
        check=False,
    )
    ansible_lint_version = s_run(
        str(cmd_prep + "ansible-lint --version --nocolor").split(),
        stdout=PIPE,
        check=True,
    )
    return_list.append(
        LintReturnObj(
            "ansible-lint",
            ansible_lint_version.stdout.decode().split()[1],
            ansible_lint_version.stdout.decode(),
            lint_result.returncode,
            lint_result.stdout.decode(),
            lint_result.stderr.decode(),
        )
    )

    return return_list


async def python_lint(
    client: Client,
    conf: ConfigObj,
    lint_sub_dict: LintSubDict,
) -> None:
    """
    Runs pylint and black on the given files
    """

    return_list = []

    exclude_set = {
        # from old project, and will eventually be removed
        "packer_w_mfa.py",
        "template_gen.py",
    }
    file_strs = [
        str(file) for file in lint_sub_dict.files if file.name not in exclude_set
    ]

    base_prep = dagger_general_prep(client, conf, "python")
    python_prepped = dagger_python_prep(conf, base_prep)

    cmd_prep = "pipenv run "

    pylint_results = (
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

    try:
        await pylint_results.exit_code(),
    except QueryError as query_err:
        click.echo("Python linting failed")
        click.echo(query_err)
        click.echo("#" * 50)
        click.echo(query_err.args)
        click.echo("#" * 50)
        click.echo(query_err.errors)
        click.echo("#" * 50)
        click.echo(query_err.__dict__)
        click.echo("#" * 50)

    click.echo(pylint_results._ctx)
    pylint_results_stdout, pylint_results_stderr, pylint_results_exitcode = (
        await pylint_results.stdout(),
        await pylint_results.stderr(),
        await pylint_results.exit_code(),
    )

    # pylint_results = s_run(
    #     str(
    #         cmd_prep
    #         # actual command
    #         + "pylint"
    #         # configuration files
    #         + f" --rcfile {Path(conf.lintrc_dir/'pylintrc')}"
    #     ).split()
    #     + file_strs,
    #     cwd=conf.git_root,
    #     stdout=PIPE,
    #     stderr=PIPE,
    #     check=False,
    # )
    pylint_version = python_prepped.with_exec(
        str(cmd_prep + "pylint --version").split(),
    )
    pylint_version_stdout = await pylint_version.stdout()
    # pylint_version = s_run(
    #     str(cmd_prep + "pylint --version").split(),
    #     stdout=PIPE,
    #     check=True,
    # )

    return_list.append(
        LintReturnObj(
            "pylint",
            pylint_version_stdout.split()[1],
            pylint_version_stdout,
            pylint_results_exitcode,
            pylint_results_stdout,
            pylint_results_stderr,
        )
    )

    black_results = s_run(
        str(
            cmd_prep
            # actual command
            + "black"
            # parameters
            + " --check --diff --color"
        ).split()
        + file_strs,
        cwd=conf.git_root,
        stdout=PIPE,
        stderr=PIPE,
        check=False,
    )

    black_version = s_run(
        str(cmd_prep + "black --version").split(),
        stdout=PIPE,
        check=True,
    )

    return_list.append(
        LintReturnObj(
            "black",
            black_version.stdout.decode().split()[1],
            black_version.stdout.decode(),
            black_results.returncode,
            black_results.stdout.decode(),
            black_results.stderr.decode(),
        )
    )

    return return_list


def terraform_lint(
    client: Client,
    _: ConfigObj,
    files: Set[Path],
) -> List[LintReturnObj]:
    """
    Runs terraform fmt on the given files
    """

    folders = list({str(file.parent) for file in files})
    return_list = []

    terraform_fmt_version = s_run(
        "terraform -version".split(),
        stdout=PIPE,
        check=True,
    )

    for folder in folders:
        s_run("terraform init".split(), cwd=folder, check=True)

        terraform_fmt_results = s_run(
            "terraform fmt -check -diff".split(),
            cwd=folder,
            stdout=PIPE,
            stderr=PIPE,
            check=False,
        )

        return_list.append(
            LintReturnObj(
                "terraform-fmt",
                terraform_fmt_version.stdout.decode().split()[1],
                terraform_fmt_version.stdout.decode(),
                terraform_fmt_results.returncode,
                terraform_fmt_results.stdout.decode(),
                terraform_fmt_results.stderr.decode(),
            )
        )
        terraform_validate_results = s_run(
            "terraform validate".split(),
            cwd=folder,
            stdout=PIPE,
            stderr=PIPE,
            check=False,
        )

        return_list.append(
            LintReturnObj(
                "terraform-validate",
                terraform_fmt_version.stdout.decode().split()[1],
                terraform_fmt_version.stdout.decode(),
                terraform_validate_results.returncode,
                terraform_validate_results.stdout.decode(),
                terraform_validate_results.stderr.decode(),
            )
        )

    return return_list


def packer_lint(
    client: Client,
    _: ConfigObj,
    files: Set[Path],
) -> List[LintReturnObj]:
    """
    Runs packer fmt on the given files
    """

    folders = list({str(file.parent) for file in files})
    return_list = []

    packer_fmt_version = s_run(
        "packer -version".split(),
        stdout=PIPE,
        check=True,
    )

    for folder in folders:
        s_run("packer init .".split(), cwd=folder, check=True)

        packer_fmt_results = s_run(
            "packer fmt -check -diff .".split(),
            cwd=folder,
            stdout=PIPE,
            stderr=PIPE,
            check=False,
        )

        return_list.append(
            LintReturnObj(
                "packer-fmt",
                packer_fmt_version.stdout.decode().strip(),
                packer_fmt_version.stdout.decode(),
                packer_fmt_results.returncode,
                packer_fmt_results.stdout.decode(),
                packer_fmt_results.stderr.decode(),
            )
        )
        packer_validate_results = s_run(
            "packer validate .".split(),
            cwd=folder,
            stdout=PIPE,
            stderr=PIPE,
            check=False,
        )

        return_list.append(
            LintReturnObj(
                "packer-validate",
                packer_fmt_version.stdout.decode().strip(),
                packer_fmt_version.stdout.decode(),
                packer_validate_results.returncode,
                packer_validate_results.stdout.decode(),
                packer_validate_results.stderr.decode(),
            )
        )

    return return_list


def shell_lint(
    client: Client,
    conf: ConfigObj,
    files: Set[Path],
) -> List[LintReturnObj]:
    """
    Runs shell linting (shellcheck & shfmt) on the given files
    """

    return_list = []
    file_strs = [str(file) for file in files]

    shellcheck_results = s_run(
        str(
            # actual command
            "shellcheck"
            # parameters
            + " -S warning"
        ).split()
        + file_strs,
        cwd=conf.git_root,
        stdout=PIPE,
        stderr=PIPE,
        check=False,
    )
    shellcheck_version = s_run(
        str("shellcheck --version").split(),
        stdout=PIPE,
        check=True,
    )

    return_list.append(
        LintReturnObj(
            "shellcheck",
            shellcheck_version.stdout.decode().split("\n")[1].split()[1],
            shellcheck_version.stdout.decode(),
            shellcheck_results.returncode,
            shellcheck_results.stdout.decode(),
            shellcheck_results.stderr.decode(),
        )
    )

    shfmt_results = s_run(
        str("shfmt -i 2 -ci -sr -l -d").split() + file_strs,
        cwd=conf.git_root,
        stdout=PIPE,
        stderr=PIPE,
        check=False,
    )
    shfmt_version = s_run(
        "shfmt --version".split(),
        stdout=PIPE,
        check=True,
    )

    return_list.append(
        LintReturnObj(
            "shfmt",
            shfmt_version.stdout.decode(),
            shfmt_version.stdout.decode(),
            shfmt_results.returncode,
            shfmt_results.stdout.decode(),
            shfmt_results.stderr.decode(),
        ),
    )

    return return_list
