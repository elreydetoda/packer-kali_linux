from typing import List, Literal, Optional
from pydantic.dataclasses import dataclass as py_dataclass

from misc import PydanticVersion


@py_dataclass
class BuildReturnObj:
    """
    The result of a build
    """

    build_version: Literal["default", "light", "min"]
    builder_name: Literal["virtualbox", "vmware", "qemu"]
    builder_version: PydanticVersion
    return_code: int
    return_stdout: str
    return_stderr: Optional[str] = None


@py_dataclass
class BuildMetaObj:
    """
    The metadata around a build
    """

    packer_version: PydanticVersion
    packer_full_version: str
    build_results: List[BuildReturnObj]

    # pylint: disable=missing-class-docstring
    class Config:
        arbitrary_types_allowed = True
