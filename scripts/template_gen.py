#!/usr/bin/env python3

import json
import pathlib
from argparse import ArgumentParser
from inspect import getframeinfo, currentframe
from pprint import pprint
from typing import NoReturn
from copy import deepcopy

# from packerlicious import Template as packer_template
from packerlicious import (
    provisioner as packer_provisioner,
    builder as packer_builder,
    post_processor as packer_post_processor
)

from bullet import Bullet, Input  # , YesNo

# TODO: add more + better logging, w/cli arg optional

# start each section with a pre-defined message and it's name
def section_meta(current_status: str, current_func: str) -> None:
    """
    this is a meta function for logging information, to help you understand
    where you are in the script if it exits early or anything else like that
    """
    # adding extra spacing
    print("")

    # using logging function to print
    logging(f"{current_status} {current_func} function")

    # adding extra spacing
    print("")


# logging func
def logging(log_str: str) -> None:
    """
    this is to help print things out nicely (since most of data is json)
    """
    pprint(log_str)


# getting pre-existing packer template from bento project
def get_packer_template(packer_template_path: pathlib) -> json:
    """
    retrienve on disk a packer template file and convert it to a dict,
    also modify it by replacing all "template_dir" with packer user variables
    """

    # replacing all instances of template_dir with a user var
    #   of bento_debian_path, because that is the location it
    #   is expecting for relative file traversal
    json_string = packer_template_path.read_text().replace(
        "template_dir", "user `bento_debian_dir`"
    )
    return json.loads(json_string)


def variable_alterations(packer_template_data: dict, new_vars: dict) -> dict:
    """
    alter the variables section of the passed in packer template
    """
    section_meta("starting", getframeinfo(currentframe()).function)

    # only selecting the vars section from the template
    variables_section = packer_template_data["variables"]

    # list of items to remove from the template
    remove_list = [
        "build_timestamp",
        "git_revision",
        "guest_additions_url",
        "iso_name",
        "mirror",
        "mirror_directory",
        "name",
        "template",
        "version",
    ]

    # removing all items in list above
    for var in remove_list:
        logging(f"removed: {var}")
        del variables_section[var]

    # either adding or updating values in template
    sub_dict = {
        "bento_debian_dir": str(new_vars["bento_debian_dir"]),
        "box_basename": str(new_vars["build_vm_base_output_name"]),
        "build_directory": "",
        "build_script_dir": str(new_vars["packer_script_dir"]),
        "cpus": new_vars["build_cpus"],
        "headless": "",
        "http_directory": str(new_vars["http_dir"]),
        "iso_checksum": "",
        "iso_url": "",
        "memory": new_vars["build_memory"],
        "preseed_path": str(new_vars["preseed_file"]),
        "template": "packerAutoKali",
        "vagrant_cloud_token": "",
        "vagrantfile": str(new_vars["vagrant_template_file"]),
        "vm_version": "",
        "vm_name": "",
    }

    logging("updating properties for variables, section")
    variables_section.update(sub_dict)

    # logging(variables_section)
    section_meta("exiting", getframeinfo(currentframe()).function)
    return packer_template_data


def sensitive_variables(packer_template_data: dict, sensitive_vars: list) -> dict:
    """
    declare the sensative variables section to help with security
    """
    section_meta("starting", getframeinfo(currentframe()).function)

    logging(f"adding variables to sensative vars secions: {', '.join(sensitive_vars)}")
    packer_template_data["sensitive-variables"] = sensitive_vars

    section_meta("exiting", getframeinfo(currentframe()).function)

    return packer_template_data


def builder_alterations(packer_template_data: dict, new_builder_data: dict) -> dict:
    """
    modify the builders section of the passed in packer data
    """
    # TODO: add format: 'ova' to vbox builder
    section_meta("starting", getframeinfo(currentframe()).function)

    packer_builder_list = packer_template_data["builders"]

    removing_builders_list = []

    for builder in packer_builder_list:
        if builder["type"] not in new_builder_data["supported_builder_list"]:
            removing_builders_list.append(builder)

    for removed_builder in removing_builders_list:
        logging(f"removing: {removed_builder['type']}")
        packer_builder_list.remove(removed_builder)

    # defining what properties have to be removed from builder
    prop_removal = ["guest_additions_url"]

    # removing properties and logging
    for prop_rm in prop_removal:
        for builder_dict in packer_builder_list:
            if prop_rm in builder_dict:
                logging(f"removed: {prop_rm} from: {builder_dict['type']}")
                del builder_dict[prop_rm]

    prop_update = {
        "iso_url": "{{ user `iso_url` }}",
        "vm_name": "{{ user `template` }}-{{ user `build_directory` }}",
    }
    # pylint: disable=line-too-long
    # reminded me to do this: https://gitlab.com/kalilinux/build-scripts/kali-vagrant/-/merge_requests/5
    # pylint: disable=line-too-long
    # additions to bento project from here: https://github.com/lavabit/robox/blob/5e9838567fc9b396ac43fc947019c7593c5c0010/generic-libvirt.json#L3437-L3442
    qemu_update = {
        "disk_interface": "virtio-scsi",
        "disk_compression": True,
        "disk_discard": "unmap",
        "disk_detect_zeroes": "unmap",
        "disk_cache": "unsafe",
        "disk_image": False,
    }
    vbox_update = {
        "gfx_controller": "vmsvga",
        "gfx_vram_size": "48"
    }

    for builder_dict in packer_builder_list:
        logging(f"updated property: {prop_update} in: {builder_dict['type']}")
        builder_dict.update(prop_update)
        # adding vbox specific properties
        if builder_dict["type"] == "virtualbox-iso":
            logging(f"updated property: {vbox_update} in: {builder_dict['type']}")
            builder_dict.update(vbox_update)
        # adding libvirt/qemu specific properties
        if builder_dict["type"] == "qemu":
            logging(f"updated property: {qemu_update} in: {builder_dict['type']}")
            builder_dict.update(qemu_update)

    # logging(packer_builder_list)

    section_meta("exiting", getframeinfo(currentframe()).function)

    return packer_template_data


def provisioner_alterations(packer_template_data: dict, new_prov_data: dict) -> dict:
    """
    modify the provisioners section of the passed in packer data
    """
    section_meta("starting", getframeinfo(currentframe()).function)

    packer_prov_list = packer_template_data["provisioners"]
    bento_prov = packer_prov_list[0]
    # creating deepcopy of env to use later, so we can alter it and it not
    #   mess up the original:
    #   https://stackoverflow.com/questions/2612802/how-to-clone-or-copy-a-list

    bento_env_vars = bento_prov["environment_vars"]
    bash_exec_cmd = bento_prov["execute_command"].replace(" sh ", " bash ")
    bento_copy_prov = deepcopy(bento_prov)

    cleanup_scripts = []

    # minimize.sh
    cleanup_scripts.append(bento_prov["scripts"].pop())
    # cleanup.sh
    cleanup_scripts.append(bento_prov["scripts"].pop())

    personal_script_dict = {
        "environment_vars": bento_env_vars,
        "execute_command": bash_exec_cmd,
        "expect_disconnect": "true",
        "scripts": new_prov_data["scripts_custom_list"],
    }

    packerlicious_prov = packer_provisioner.Shell().from_dict(
        title="CustomSystemScripts", d=personal_script_dict
    )
    # adding my custom scripts
    packer_prov_list.insert(0, packerlicious_prov.to_dict())
    # packer_prov_list.append(packerlicious_prov.to_dict())

    ## SHELL: move last 2 scripts (cleanup) to bottom
    # clearing scripts section of all previous scripts
    bento_copy_prov["scripts"].clear()

    for script in reversed(cleanup_scripts):
        bento_copy_prov["scripts"].append(script)

    # removing for packerlicious usage
    del bento_copy_prov["type"]
    # altering the the path for the cleanup.sh, so it
    # doesn't try to uninstall X11 packages
    bento_copy_prov["scripts"][0] = f"{new_prov_data['prov_packer_dir']}/cleanup.sh"

    packerlicious_prov = packer_provisioner.Shell().from_dict(
        title="CleanupBentoScripts", d=bento_copy_prov
    )

    packer_prov_list.append(packerlicious_prov.to_dict())

    # print(json.dumps(packer_prov_list, indent=2))
    section_meta("exiting", getframeinfo(currentframe()).function)
    return packer_template_data


def post_processor_alterations(packer_template_data: dict, new_post_data: dict) -> dict:
    """
    modify the post-processors section of the passed in packer data
    """
    section_meta("starting", getframeinfo(currentframe()).function)
    post_processor_list = packer_template_data["post-processors"]

    # updating vagrant processor
    post_processor_list[0].update(
        {
            "compression_level": 9,
            "vagrantfile_template": "{{ user `vagrantfile` }}",
            # needed for this: https://www.packer.io/docs/post-processors/amazon-import
            "keep_input_artifact": True,
        }
    )

    vagrant_cloud_post_processor = packer_post_processor.VagrantCloud().from_dict(
        title="VagrantCloudPP", d=new_post_data["vagrant-cloud"]
    )

    box_output_path = pathlib.Path(post_processor_list[0]["output"])

    vagrant_cloud_artiface_dict = {"files": [str(box_output_path)]}

    vagrant_cloud_artiface_post_processor = packer_post_processor.Artifice().from_dict(
        title="VagrantCloud", d=vagrant_cloud_artiface_dict
    )

    post_processor_list.append(
        [
            vagrant_cloud_artiface_post_processor.to_dict(),
            vagrant_cloud_post_processor.to_dict(),
        ]
    )

    # print(json.dumps(post_processor_list, indent=2))
    section_meta("exiting", getframeinfo(currentframe()).function)
    return packer_template_data


def write_packer_template(
    packer_template_path: pathlib, packer_template_data: dict
) -> NoReturn:
    """
    write the post processors section to disk
    """
    section_meta("starting", getframeinfo(currentframe()).function)

    # logging(packer_template_data)
    packer_template_path.write_text(
        json.dumps(packer_template_data, indent=2), encoding="utf-8"
    )

    section_meta("exiting", getframeinfo(currentframe()).function)


def get_builder_aws_ebs() -> packer_builder:
    """
    build the aws builder section
    """
    section_meta("starting", getframeinfo(currentframe()).function)

    variable_dictionary = {
        "source_ami": "{{ user `kali_aws_ami` }}",
        "region": "{{ user `aws_region` }}",
        "ssh_username": "kali",
        "instance_type": "t2.medium",
        "ami_name": "Kali Linux (Standard)",
        "ami_users": [""],
        "force_deregister": "true",
        "force_delete_snapshot": "true",
    }

    auth_prompt = Bullet(
        prompt="Choose from the items below: ",
        choices=["AWS Profile", "AWS Access Key"],
    )

    auth_type = auth_prompt.launch()

    if auth_type == "AWS Profile":
        profile_prompt = Input(
            prompt="Please input the profile you would like to use: "
        )
        current_profile = profile_prompt.launch()

        variable_dictionary.update({"profile": f"{current_profile}"})

    elif auth_type == "AWS Access Key":

        variable_dictionary.update(
            {
                "access_key": "{{ user `aws_access_key` }}",
                "secret_key": "{{ user `aws_secret_key` }}",
            }
        )

    else:
        print(f"unknown auth type: {auth_type}")

    aws_ebs_builder = packer_builder.AmazonEbs().from_dict(
        "AmazonEBS", d=variable_dictionary
    )
    # TODO: fixin base package to accept string
    aws_ebs_builder_dict = aws_ebs_builder.to_dict()
    aws_ebs_builder_dict["ami_users"] = "{{user `ami_users`}}"
    section_meta("exiting", getframeinfo(currentframe()).function)
    return aws_ebs_builder_dict


def get_builder_hyperv( packer_template_data: dict ) -> packer_builder:
    """
    build the aws builder section
    """
    section_meta("starting", getframeinfo(currentframe()).function)

    packer_builder_list = packer_template_data["builders"]

    wanted_keys = [
        'boot_command',
        'boot_wait',
        'cpus',
        'disk_size',
        'http_directory',
        'iso_checksum',
        'iso_url',
        'memory',
        'output_directory',
        'shutdown_command',
        'ssh_password',
        'ssh_port',
        'ssh_timeout',
        'ssh_username',
        'vm_name',
        'headless'
    ]

    variable_dictionary = {
        'generation': 1,
        'type': 'hyperv-iso'
    }

    for wanted_key in wanted_keys:
        current_value = packer_builder_list[0][wanted_key]
        if wanted_key == 'output_directory':
            # replacing whatever provider was present with hyperv
            current_value = '-'.join(current_value.split('-')[:-1]) + '-hyperv'
            logging(f'updating property: {current_value}')
        variable_dictionary[wanted_key] = current_value

    # hyperv_builder = packer_builder.HypervIso().from_dict(
    #     "HyperVISO", d=variable_dictionary
    # )
    logging(f'adding builder: {variable_dictionary["type"]}')

    section_meta("exiting", getframeinfo(currentframe()).function)
    return variable_dictionary


def append_builder(packer_template_data: dict, new_builder: dict) -> dict:
    """
    add given builder to packer template blob
    """
    section_meta("starting", getframeinfo(currentframe()).function)

    packer_template_data["builders"].append(new_builder)

    section_meta("exiting", getframeinfo(currentframe()).function)

    return packer_template_data


# pylint: disable=C0116,too-many-statements
def main():

    ### section with lots of variables to get used throughout the script

    ## General

    # directory where the script is currently at, which should be
    #   the scripts folder
    script_dir = pathlib.Path(__file__).parent

    # project root directory
    project_root = script_dir.parent

    # packer provisioning scripts dir
    prov_packer_dir = project_root / "prov_packer"

    new_packer_template = project_root / "kali-template.json"

    http_preseed_dir = project_root / "install" / "http"
    # TODO: handle when variables.json doesn't exist and default to below
    # http_preseed_file = 'kali-linux-rolling-preseed.cfg'
    http_preseed_file = ''
    vagrant_template_file = project_root / "install" / "vagrantfile-kali_linux.template"

    build_cpus = "2"
    build_memory = "4096"
    build_vm_output_dir = project_root
    build_vm_base_output_name = "red-automated_kali"

    ## builders section of variables
    supported_builder_list = [
        "virtualbox-iso",
        "vmware-iso",
        "aws-ebs",
        "qemu",
        # don't have a way to test this...
        # 'parallels-iso'
    ]
    ## provisioner section of variables
    scripts_removal_list = ["virtualbox.sh"]
    prov_packer_dir_str = str(prov_packer_dir)
    scripts_custom_list = [
        f"{prov_packer_dir_str}/full-update.sh",
        f"{prov_packer_dir_str}/vagrant.sh",
        f"{prov_packer_dir_str}/customization.sh",
        f"{prov_packer_dir_str}/docker.sh",
        f"{prov_packer_dir_str}/networking.sh",
        f"{prov_packer_dir_str}/virtualbox.sh",
    ]

    parser = ArgumentParser(
        description="""
    This script is used to generate the packer file template
    for doing an auotmated kali installation
    """
    )

    parser.add_argument(
        "-a", "--aws", action="store_true", help="also build the aws-ebs builder"
    )
    parser.add_argument(
        "-p", "--post-provisioner", action="store_false", default=True,
        help="Do not add additional post provisioners (defaults to including all post provisioners)"
    )
    parser.add_argument(
        "-ap", "--add-post-provisioner",
        help="path to file where the json for another post povisioner is located"
    )
    parser.add_argument(
        "-rv", "--remove-vagrant",action="store_true",
        help="remove the vagrant post processor completely"
    )

    # parser.add_argument(
    #     '-b','--builders', nargs='*', default=[ 'all' ],
    #     help='''
    #         a space delimited list, which is all the builders you want
    #         to build. currently supported builders are: {}
    #         '''.format('. '.join(supported_builder_list))
    # )
    args = parser.parse_args()

    ## Bento

    # bento dir
    bento_base_dir = prov_packer_dir / "bento"

    # bento packer_templates dir
    bento_packer_template = bento_base_dir / "packer_templates"

    # necessary folder in packer templates dir
    bento_debian_dir = bento_packer_template / "debian"

    bento_current_packer_template = bento_debian_dir / "debian-10.5-amd64.json"

    ###

    # read in bento template
    old_packer_data = get_packer_template(bento_current_packer_template)

    ### variable alterations section
    # variables to update
    new_variables = {
        "bento_debian_dir": bento_debian_dir,
        "packer_script_dir": prov_packer_dir,
        "http_dir": http_preseed_dir,
        "preseed_file": http_preseed_file,
        "project_root": project_root,
        "build_cpus": build_cpus,
        "build_memory": build_memory,
        "vagrant_template_file": vagrant_template_file,
        "build_vm_output_dir": build_vm_output_dir,
        "build_vm_base_output_name": build_vm_base_output_name,
    }

    # updating variables
    updated_packer_data = variable_alterations(old_packer_data, new_variables)

    ### sensitive variables section
    # list of sensitive variables
    sensitive_var_list = ["vagrant_cloud_token"]

    # adding list of sensative variables
    updated_packer_data = sensitive_variables(updated_packer_data, sensitive_var_list)

    # TODO: fix logic error to where other builders are looped over here
    #   when 'all' is the array
    ### builder alterations section
    builder_info_dict = {"supported_builder_list": supported_builder_list}
    updated_packer_data = builder_alterations(updated_packer_data, builder_info_dict)

    append_builder(updated_packer_data, get_builder_hyperv(updated_packer_data))

    if args.aws:
        append_builder(updated_packer_data, get_builder_aws_ebs())

    ### provisioner alterations section
    prov_info_dict = {
        "prov_packer_dir": prov_packer_dir,
        "scripts_removal_list": scripts_removal_list,
        "scripts_custom_list": scripts_custom_list,
    }
    updated_packer_data = provisioner_alterations(updated_packer_data, prov_info_dict)

    ### post provisioner alterations section
    post_processor_dict = {
        # configured in the post_processor_alterations func
        "vagrant-cloud-artiface": {},
        "vagrant-cloud": {
            "box_tag": "{{user `vm_name`}}",
            "access_token": "{{user `vagrant_cloud_token`}}",
            "version": "{{user `vm_version`}}",
        },
    }

    if args.remove_vagrant:
        for i in range(len(updated_packer_data["post-processors"])):
            if updated_packer_data["post-processors"][i]["type"] == 'vagrant':
                del updated_packer_data["post-processors"][i]
        if len(updated_packer_data["post-processors"]) == 0:
            del updated_packer_data["post-processors"]
    else:
        if not args.aws:
            if args.post_provisioner:
                updated_packer_data = post_processor_alterations(
                    updated_packer_data, post_processor_dict
                )
        elif args.aws:
            del updated_packer_data["post-processors"]

    if args.add_post_provisioner:
        print()
        # updated_packer_data = post_processor_alterations(
        #     updated_packer_data,
        # )
    # logging(updated_packer_data)

    # writing out to file
    write_packer_template(new_packer_template, updated_packer_data)


if __name__ == "__main__":
    main()
