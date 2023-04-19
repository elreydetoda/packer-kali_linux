from abc import ABC
import re
from typing import Final, Optional
from tempfile import TemporaryDirectory
from pathlib import Path

from gnupg import GPG
from loguru import logger
from requests import get as r_get
from pydantic import HttpUrl

BASE_KALI_DOMAIN: Final[str] = "kali.org"
BASE_KALI_DOWNLOAD_URL: Final[HttpUrl] = f"https://cdimage.{BASE_KALI_DOMAIN}/current"
KALI_ISO_RE: Final[
    re.Pattern
] = r"kali-linux-[\w\.]+-installer-netinst-amd64\.iso(?!\.torrent)"


class KaliIso(ABC):
    def __init__(self, kali_iso_name: Optional[str] = None) -> None:
        super().__init__()
        self._kali_iso_name = kali_iso_name
        self.gpg_stderr = None

    @property
    def iso_name(self) -> HttpUrl:
        """
        the iso name either provided by the user or
        the latest kali iso name
        """
        if self._kali_iso_name is None:
            return self._get_latest_kali_iso_name()
        return self._kali_iso_name

    @property
    def iso_url(self) -> HttpUrl:
        """
        the url for the iso_name property
        """
        return f"{BASE_KALI_DOWNLOAD_URL}/{self.iso_name}"

    @property
    def iso_checksum(self) -> str:
        """
        the checksum for the iso_name property
        """
        checksums = r_get(
            f"{BASE_KALI_DOWNLOAD_URL}/SHA256SUMS", timeout=30
        ).content.decode()
        return re.search(
            r"(?P<checksum>[\w]+)\s+" + KALI_ISO_RE,
            checksums,
        ).group("checksum")

    def _get_latest_kali_iso_name(self) -> str:
        """
        Get the latest Kali ISO URL
        """
        current_isos = r_get(BASE_KALI_DOWNLOAD_URL, timeout=30).content.decode()
        iso_name = re.search(KALI_ISO_RE, current_isos)

        return iso_name.group()

    @staticmethod
    def _get_public_key() -> str:
        """
        Get the public key
        """
        return r_get(
            f"https://archive.{BASE_KALI_DOMAIN}/archive-key.asc", timeout=30
        ).content.decode()

    @staticmethod
    def _get_checksum_sig() -> bytes:
        """
        Get the checksum signature
        """
        return r_get(f"{BASE_KALI_DOWNLOAD_URL}/SHA256SUMS.gpg", timeout=30).content

    @staticmethod
    def _get_checksum_file() -> bytes:
        """
        Get the checksum file
        """
        return r_get(f"{BASE_KALI_DOWNLOAD_URL}/SHA256SUMS", timeout=30).content

    def validate(
        self,
    ) -> bool:
        """
        Validate the Kali ISO checksum signature
        """

        gpg = GPG()
        gpg.import_keys(self._get_public_key())

        with TemporaryDirectory() as tmpdir:
            logger.debug(f"Temp dir: {tmpdir}")
            checksum = Path(f"{tmpdir}/checksums")
            checksum.write_bytes(self._get_checksum_file())
            sig_file = Path(f"{tmpdir}/SHA256SUMS.gpg")
            sig_file.write_bytes(self._get_checksum_sig())
            with sig_file.open("rb") as sig:
                verification_result = gpg.verify_file(
                    sig,
                    checksum,
                )
        # This didn't seem to work properly, so using temporary directory
        #   + verify_file instead (that's currently working)
        # verification_result = gpg.verify_data(
        #     self._get_checksum_sig(),
        #     ,
        # )
        # pylint: disable=no-member
        self.gpg_stderr = verification_result.stderr
        logger.trace(f"Verification result: {verification_result.valid}")
        logger.trace(f"Return code: {verification_result.returncode}")
        # pylint: disable=no-member
        logger.trace(f"Stderr: {verification_result.stderr}")
        # logger.debug(f"Stdout: {verification_result.stdout}")
        return verification_result.valid
