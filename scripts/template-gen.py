#!/usr/bin/env python3
import json
import pathlib
from inspect import getframeinfo, currentframe
from pprint import pprint
from typing import NoReturn

# start each section with a pre-defined message and it's name
def section_meta(current_status: str, current_func: str) -> NoReturn:
    # adding extra spacing
    print('')

    # using logging function to print
    logging('{} {} function'.format(current_status, current_func))

    # adding extra spacing
    print('')

# logging func
def logging(log_str: str) -> NoReturn:
    pprint(log_str)

# getting pre-existing packer template from bento project
def get_packer_template(packer_template_path: pathlib) -> json:

    # replacing all instances of template_dir with a user var
    #   of bento_debian_path, because that is the location it
    #   is expecting for relative file traversal
    json_string = packer_template_path.read_text().replace('template_dir', 'user `bento_debian_dir`')
    return json.loads(json_string)

def variable_alterations(packer_template_data: dict, new_vars: dict) -> dict:
    section_meta('starting', getframeinfo(currentframe()).function)

    # only selecting the vars section from the template
    variables_section = packer_template_data['variables']


    # list of items to remove from the template
    remove_list = [
        'build_timestamp',
        'git_revision',
        'guest_additions_url',
        'iso_name',
        'mirror',
        'mirror_directory',
        'name',
        'template',
        'version'
        ]
    
        # removing all items in list above
    for var in remove_list:
        logging('removed: {}'.format(var))
        del variables_section[var]

    # either adding or updating values in template
    sub_dict = {
        'bento_debian_dir': str(new_vars['bento_debian_dir']),
        'box_basename': '',
        'build_directory': str(new_vars['project_root']),
        'build_script_dir': str(new_vars['packer_script_dir']),
        'cpus': new_vars['build_cpus'],
        'headless': '',
        'http_directory': str(new_vars['http_dir']),
        'iso_checksum': '',
        'iso_checksum_type': '',
        'iso_url': '',
        'memory': new_vars['build_memory'],
        'preseed_path': str(new_vars['preseed_file']),
        'template': 'packerAutoKali',
        'vagrant_cloud_token': '',
        'vm_version': '',
        'vm_name': ''
    }

    logging('updating properties for variables, section')
    variables_section.update(sub_dict)

    # logging(variables_section)
    section_meta('exiting', getframeinfo(currentframe()).function)
    return packer_template_data

def sensitive_variables(packer_template_data: dict, sensitive_vars: list) -> dict:
    section_meta('starting', getframeinfo(currentframe()).function)

    logging(
        'adding variables to sensative vars secions: {}'.format(
            ', '.join(sensitive_vars)
            )
    )
    packer_template_data['sensitive-variables'] = sensitive_vars

    section_meta('exiting', getframeinfo(currentframe()).function)

    return packer_template_data

def builder_alterations(packer_template_data: dict, new_builder_data: dict) -> dict:
    section_meta('starting', getframeinfo(currentframe()).function)

    packer_builder_list = packer_template_data['builders']

    removing_builders_list = []

    for builder in packer_builder_list:
        if builder['type'] not in new_builder_data['supported_builder_list']:
            removing_builders_list.append(builder)
    
    for removed_builder in removing_builders_list:
        logging('removing: {}'.format(removed_builder['type']))
        packer_builder_list.remove(removed_builder)

    # defining what properties have to be removed from builder
    prop_removal = [ 'guest_additions_url' ]

    # removing properties and logging
    for prop_rm in prop_removal:
        for builder_dict in packer_builder_list:
            if prop_rm in builder_dict:
                logging('removed: {} from: {}'.format(prop_rm, builder_dict['type']))
                del builder_dict[prop_rm]

    prop_update = {
        'iso_url': '{{ user `iso_url` }}'
    }

    for builder_dict in packer_builder_list:
        logging('updated property: {} in: {}'.format(prop_update, builder_dict['type']))
        builder_dict.update(prop_update)

    # logging(packer_builder_list)

    section_meta('exiting', getframeinfo(currentframe()).function)

    return packer_template_data

def main():

    ### section with lots of variables to get used throughout the script

    ## General

    # directory where the script is currently at, which should be
    #   the scripts folder
    script_dir = pathlib.Path(__file__).parent

    # project root directory
    project_root = script_dir.parent

    # packer provisioning scripts dir
    prov_packer_dir = project_root / 'prov_packer'

    new_packer_template = project_root / 'kali-template.json'

    http_preseed_dir = project_root / 'install' / 'http'
    http_preseed_file = 'kali-linux-rolling-preseed.cfg'

    build_cpus = '2'
    build_memory = '4096'

    ## builders section of variables
    supported_builder_list = [ 'virtualbox-iso', 'vmware-iso' ]
    ## Bento

    # bento dir
    bento_base_dir = prov_packer_dir / 'bento'

    # bento packer_templates dir
    bento_packer_template = bento_base_dir / 'packer_templates'

    # necessary folder in packer templates dir
    bento_common_scripts = bento_packer_template / '_common'
    bento_debian_dir = bento_packer_template / 'debian'

    bento_current_packer_template = bento_debian_dir / 'debian-10.5-amd64.json'

    ###

    # read in bento template
    old_packer_data = get_packer_template(bento_current_packer_template)

    ### variable alterations section
    # variables to update
    new_variables = {
        'bento_debian_dir': bento_debian_dir,
        'packer_script_dir': prov_packer_dir,
        'http_dir': http_preseed_dir,
        'preseed_file': http_preseed_file,
        'project_root': project_root,
        'build_cpus': build_cpus,
        'build_memory': build_memory
    }

    # updating variables
    updated_packer_data = variable_alterations(old_packer_data, new_variables)

    ### sensitive variables section
    # list of sensitive variables
    sensitive_var_list = [
        'vagrant_cloud_token'
    ]

    # adding list of sensative variables
    updated_packer_data = sensitive_variables(updated_packer_data, sensitive_var_list)

    ### builder alterations section
    builder_info_dict = {
        'supported_builder_list': supported_builder_list       
    }
    builder_alterations(updated_packer_data, builder_info_dict)
    logging(updated_packer_data)
    # print(type(old_packer_data))
    # print(old_packer_data)
    # pprint(old_packer_data, indent=2)
    # print(old_packer_data.exists())

    # # altering builders section of packer json template
    # updated_obj = builders_alterations(updated_obj)

    # # altering provisioners section of packer json template
    # updated_obj = prov_alterations(updated_obj)

    # # adding to post-processors
    # updated_obj = post_processor_alteration(updated_obj)

    # # logging final object
    # # logging(updated_obj)

    # # writing out to file
    # new_packer_template.write_text(json.dumps(old_packer_data, indent=2), encoding='utf-8')

if __name__ == "__main__":
    main()
