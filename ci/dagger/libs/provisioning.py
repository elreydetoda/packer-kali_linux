from os import getenv
from json import dumps as j_dumps

import click
from dagger import Client

from models.config import ConfigObj
from libs.helper import (
    ansible_playbook_cmd,
    dagger_handle_query_error,
    dagger_prod_ansible_full_wrapper,
)


async def provision(client: Client, conf: ConfigObj):
    """Bootstrap the provisioning process."""
    # default values
    # extra_flags = ""
    extra_vars = {}
    extra_vars_list = None

    (
        provisioning_prepped,
        inventory,
        extra_flags,
    ) = await dagger_prod_ansible_full_wrapper(
        client,
        conf,
        extra_vars,
    )

    vmware_lic = getenv("VMWARE_LICENSE")
    if vmware_lic:
        vmware_secret = client.set_secret("vmware_license", vmware_lic)
        extra_vars["vmware_license"] = await vmware_secret.plaintext()
    if extra_vars:
        extra_vars_list = ["-e", j_dumps(extra_vars)]

    return await dagger_handle_query_error(
        provisioning_prepped
        # provisioning machine's with all hypervisors
        .with_exec(
            ansible_playbook_cmd(
                inventory,
                "ci/ansible/bootstrap-playbook.yml",
                extra_flags=extra_flags,
            ).split()
            # adding extra varaibles
            + (extra_vars_list or [])
        )
    )
