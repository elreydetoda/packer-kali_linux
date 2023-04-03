from pathlib import Path
from subprocess import run as s_run, PIPE
from typing import List, Set
import click

from click.core import Context as click_Context

from models.config import ConfigObj
from models.helper import LintReturnObj

from automation import find


def prep_lint(
    base_key: str,
    ctx: click_Context,
    return_dict: dict,
) -> None:
    """
    Prepares the linting process by finding all the files to lint,
    and also setting some default values
    """

    conf: ConfigObj = ctx.obj["CONFIG"]

    return_dict.setdefault(base_key, {})
    return_dict[base_key]["files"] = set()
    return_dict[base_key]["results"] = []

    for pattern in conf.config_data[base_key]["patterns"]:
        result = ctx.invoke(find, pattern=pattern)
        return_dict[base_key]["files"].update(result)


def ansible_lint(conf: ConfigObj, files: Set[Path]) -> List[LintReturnObj]:
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


def python_lint(conf: ConfigObj, files: Set[Path]) -> List[LintReturnObj]:
    """
    Runs pylint and black on the given files
    """

    return_list = []
    exclude_set = {
        "packer_w_mfa.py",
        "template_gen.py",
    }
    file_strs = [str(file) for file in files if file.name not in exclude_set]

    cmd_prep = "pipenv run "

    pylint_results = s_run(
        str(
            cmd_prep
            # actual command
            + "pylint"
            # configuration files
            + f" --rcfile {Path(conf.lintrc_dir/'pylintrc')}"
        ).split()
        + file_strs,
        cwd=conf.git_root,
        stdout=PIPE,
        stderr=PIPE,
        check=False,
    )
    pylint_version = s_run(
        str(cmd_prep + "pylint --version").split(),
        stdout=PIPE,
        check=True,
    )

    return_list.append(
        LintReturnObj(
            "pylint",
            pylint_version.stdout.decode().split()[1],
            pylint_version.stdout.decode(),
            pylint_results.returncode,
            pylint_results.stdout.decode(),
            pylint_results.stderr.decode(),
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


def terraform_lint(_: ConfigObj, files: Set[Path]) -> List[LintReturnObj]:
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


def packer_lint(_: ConfigObj, files: Set[Path]) -> List[LintReturnObj]:
    """
    Runs packer fmt on the given files
    """

    folders = list({str(file.parent) for file in files})
    click.echo(folders)
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
