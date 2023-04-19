from typing import Literal, Optional, Tuple
from loguru import logger
from pydantic import HttpUrl, constr, root_validator
from pydantic.dataclasses import dataclass as py_dataclass

from models.misc import SemanticVersion
from libs.builder import KaliIso
from libs.vagrant_cloud import VagrantCloud


@py_dataclass
class BuildPrepMeta:
    """
    The metadata around a packer build command
    """

    vagrant_cloud_user: constr(strip_whitespace=True)
    build_version: Literal["default", "light", "min"]
    providers: Tuple[Literal["virtualbox", "vmware", "qemu"], ...]


@py_dataclass
class BuildTaskMeta:
    """
    This is the task that is passed to the build queue
    """

    metadata: BuildPrepMeta
    provider: Literal["virtualbox", "vmware", "qemu"]
    vm_version: Optional[SemanticVersion] = None
    vm_name: Optional[constr(strip_whitespace=True)] = None

    @root_validator()
    def _default_files(cls, values: dict):  # pylint: disable=no-self-argument
        cls._generate_vm_name(values)
        cls._generate_vm_version(values)
        return values

    @classmethod
    def _generate_vm_name(cls, values: dict):
        value = values.get("vm_name")
        if value is None:
            version = (
                f"-{values.get('metadata').build_version}"
                if values.get("metadata").build_version != "default"
                else ""
            )
            dev_ver = True
            values["vm_name"] = f"kali{version}-linux_amd64{'-dev' if dev_ver else ''}"
        logger.debug(f"vm_name: {values['vm_name']}")
        return values

    @classmethod
    def _generate_vm_version(cls, values):
        value = values.get("vm_version")
        if value is None:
            values["vm_version"] = VagrantCloud(
                values.get("metadata").vagrant_cloud_user,
                values.get("provider"),
                values.get("vm_name"),
                need_token=False,
            ).vm_version
        logger.debug(f"vm_version: {values['vm_version']}")
        return values


@py_dataclass
class KaliIsoMeta:
    iso_checksum: Optional[str] = None
    iso_url: Optional[HttpUrl] = None

    @root_validator()
    def _default_files(cls, values: dict):  # pylint: disable=no-self-argument
        cls._generate_iso_url(values)
        cls._generate_iso_checksum(values)
        return values

    @classmethod
    def _generate_iso_url(cls, values):
        value = values.get("iso_url")
        if value is None:
            values["iso_url"] = KaliIso().iso_url
        logger.debug(f"iso_url: {values['iso_url']}")
        return values

    @classmethod
    def _generate_iso_checksum(cls, values):
        value = values.get("iso_checksum")
        if value is None:
            kali_iso = KaliIso()
            if kali_iso.validate():
                values["iso_checksum"] = kali_iso.iso_checksum
            else:
                raise ValueError(f"Invalid ISO checksum: {kali_iso.gpg_stderr}")
        logger.debug(f"iso_checksum: {values['iso_checksum']}")
        return values
