from typing import Tuple

from dagger import Client

from models.misc import DaggerExecResult
from models.config import ConfigObj
from libs.helper import (
    dagger_general_prep,
    dagger_handle_query_error,
    dagger_terraform_deployment_prep,
    dagger_terraform_prep,
)


async def deploy(client: Client, conf: ConfigObj) -> Tuple[str, DaggerExecResult]:
    """
    Deploys the servers for the builds to run on
    """
    base_prep = dagger_general_prep(client, conf, "terraform")
    terraform_prep = await dagger_terraform_prep(client, base_prep)

    terraform_version = await dagger_handle_query_error(
        terraform_prep.with_exec("-version".split()), False
    )

    deployment_prep = dagger_terraform_deployment_prep(
        client,
        terraform_prep,
        conf.config_data["terraform"]["deployment_folder"],
    )

    terraform_deployed = (
        deployment_prep
        # deploying the servers
        .with_exec("apply -auto-approve".split())
    )

    terraform_deployed_results = await dagger_handle_query_error(
        terraform_deployed, False
    )
    return (terraform_version.stdout.split()[1], terraform_deployed_results)


async def destroy(client: Client, conf: ConfigObj) -> Tuple[str, DaggerExecResult]:
    """
    Deploys the servers for the builds to run on
    """
    base_prep = dagger_general_prep(client, conf, "terraform")
    terraform_prep = await dagger_terraform_prep(client, base_prep)

    terraform_version = await dagger_handle_query_error(
        terraform_prep.with_exec("-version".split()), False
    )

    deployment_prep = dagger_terraform_deployment_prep(
        client,
        terraform_prep,
        conf.config_data["terraform"]["deployment_folder"],
    )

    terraform_deployed = (
        deployment_prep
        # deploying the servers
        .with_exec("destroy -auto-approve".split())
    )

    terraform_deployed_results = await dagger_handle_query_error(
        terraform_deployed, False
    )
    return (terraform_version.stdout.split()[1], terraform_deployed_results)
