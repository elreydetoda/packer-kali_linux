from abc import ABC
from os import getenv
from loguru import logger

from requests import get as r_get


class VagrantCloud(ABC):
    """
    Used to handle all Vagrant Cloud API calls
    """

    def __init__(
        self,
        username: str,
        provider: str,
        box_name: str,
        need_token: bool = True,
    ) -> None:
        super().__init__()
        self.auth_token = getenv("VAGRANT_CLOUD_TOKEN")
        if self.auth_token is None and need_token:
            raise ValueError("VAGRANT_CLOUD_TOKEN is not set")
        self.username = username
        self.provider = provider
        self.box_name = box_name

    @property
    def vm_version(self) -> str:
        """
        the version of the VM to build
        """
        return self._get_latest_version()

    def _get_box_url(self) -> str:
        return f"https://app.vagrantup.com/api/v1/box/{self.username}/{self.box_name}"

    def _get_latest_version(self) -> str:
        """
        Get the latest version of the box
        """
        logger.debug(f"box_url: {self._get_box_url()}")
        box = r_get(self._get_box_url(), timeout=30).json()
        return box["current_version"]["version"]
