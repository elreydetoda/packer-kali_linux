from pathlib import Path
from typing import Optional, Set, List

from pydantic import BaseModel
from pydantic.dataclasses import dataclass as py_dataclass
from packaging.version import Version


class PydanticVersion(Version):
    @classmethod
    def __get_validators__(cls):
        yield cls.validate

    @classmethod
    def validate(cls, v):
        """
        Validate the version string.
        """
        if isinstance(v, Version):
            return v
        if isinstance(v, str):
            return Version(v)
            # if v.startswith("v"):
            #     return Version(v)
            # return Version("v" + v)
        raise TypeError(f"Expected str or Version, got {type(v)}")

    def __repr__(self):
        return f"Version('{self}')"


@py_dataclass
class LintReturnObj:
    tool_name: str
    tool_version: PydanticVersion
    full_version: str
    return_code: int
    return_stdout: str
    return_stderr: Optional[str] = None
    cwd: Optional[Path] = None

    def __hash__(self) -> int:
        return hash(self.tool_name) ^ hash(self.return_code)

    class Config:
        arbitrary_types_allowed = True


class LintSubDict(BaseModel):
    files: Optional[Set[Path]] = set()
    results: Optional[List[LintReturnObj]] = []
