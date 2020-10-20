#!/usr/bin/env python3

import pathlib
import configparser
from datetime import timedelta
# from pprint import pprint
from bullet import Bullet, Input
from boto3 import client


def get_profile(aws_config_path):
    '''
    getting your aws profile input from user
    '''

    config = configparser.ConfigParser()
    config.read(aws_config_path)

    # constructing prompt for user input
    aws_profile_prompt = Bullet(
        prompt = 'Choose from the items below: ',
        choices = config.sections()
    )

    # getting user input for which profile is wanted
    aws_profile = aws_profile_prompt.launch()


    # print(config[aws_profile]['mfa_serial'])
    return config[aws_profile]

def get_session(mfa_serial_str: str, mfa_code: str,
    session_duration: int = timedelta(hours=4).seconds):
    '''
    getting a session from sts service on amazon
    '''

    sts_obj = client('sts')
    sts_creds = sts_obj.get_session_token(
        DurationSeconds = session_duration,
        SerialNumber = mfa_serial_str,
        TokenCode = mfa_code
    )
    return sts_creds['Credentials']

def write_setup(aws_cred_path, temp_creds: dict, provisioning_profile: dict,
    profile_name: str = 'prov-packer'):
    '''
    write out new aws config and creds
    '''

    config = configparser.ConfigParser()
    config.read(aws_cred_path)

    config[profile_name] = {
        'aws_access_key_id': temp_creds['AccessKeyId'],
        'aws_secret_access_key': temp_creds['SecretAccessKey'],
        'aws_session_token': temp_creds['SessionToken']
    }
    config.write(aws_cred_path.open('w'))

    config.clear()

    config['profile {}'.format(profile_name)] = {
        'region': provisioning_profile['region'],
        'role_arn': provisioning_profile['role_arn']
    }

def main():
    default_aws_dir = pathlib.Path().home() / '.aws'
    default_aws_config = default_aws_dir / 'config'
    default_aws_creds = default_aws_dir / 'credentials'
    current_mfa_prompt = Input(
        prompt = 'Please input your current mfa code: '
    )
    current_mfa = current_mfa_prompt.launch()
    profile_config = get_profile(default_aws_config)

    aws_session = get_session(mfa_serial_str = profile_config['mfa_serial'], mfa_code = current_mfa)

    write_setup(aws_cred_path =  default_aws_creds, temp_creds = aws_session,
        provisioning_profile = profile_config)

if __name__ == "__main__":
    main()
