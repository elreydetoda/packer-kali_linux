import click
from dagger import Client

from models.config import ConfigObj


async def provision(client: Client, conf: ConfigObj):
    """Bootstrap the provisioning process."""
    click.echo("Provisioning")
