from os import getenv
from json import dumps as j_dumps

import click
from dagger import Client

from models.config import ConfigObj
from libs.helper import (
    ansible_playbook_cmd,
    dagger_ansible_prep,
    dagger_ansible_production_prep,
    dagger_general_prep,
    dagger_handle_query_error,
    dagger_python_prep,
)


async def provision(client: Client, conf: ConfigObj):
    """Bootstrap the provisioning process."""
    # default values
    extra_flags = ""
    extra_vars = {}
    extra_vars_list = None

    ansible_cfg_data = conf.config_data["ansible"]
    ansible_base = dagger_general_prep(client, conf, "python")
    python_prepped = await dagger_python_prep(client, conf, ansible_base, prod=True)
    ansible_prepped = dagger_ansible_prep(client, python_prepped)
    provisioning_prepped = dagger_ansible_production_prep(client, ansible_prepped)

    if getenv("CI"):
        inventory = ansible_cfg_data["inventories"]["prod"]
    else:
        inventory = ansible_cfg_data["inventories"]["local"]
        extra_flags = "--become"
        extra_vars["local_only"] = True

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
