from typing import List, Literal, Optional
from pydantic import BaseModel
from pydantic.dataclasses import dataclass as py_dataclass

from models.misc import PydanticVersion


@py_dataclass
class BuildReturnObj:
    """
    The result of a build
    """

    build_version: Literal["default", "light", "min"]
    builder_name: Literal["virtualbox", "vmware", "qemu"]
    builder_version: PydanticVersion
    exit_code: int
    return_stdout: str
    return_stderr: Optional[str] = None

    # pylint: disable=missing-class-docstring
    class Config:
        arbitrary_types_allowed = True


class BuildMetaObj(BaseModel):
    """
    The metadata around a build
    """

    # packer_version: PydanticVersion
    # packer_full_version: str
    # vagrant_version: PydanticVersion
    # vagrant_full_version: str
    build_results: Optional[List[BuildReturnObj]] = []
