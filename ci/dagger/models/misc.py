from typing import Optional

from pydantic import Field
from pydantic.dataclasses import dataclass as py_dataclass
from packaging.version import Version


@py_dataclass
class DaggerExecResult:
    """
    The result of a dagger query execution, based on:
    https://github.com/dagger/dagger/issues/4706#issuecomment-1499371201
    """

    class Config:
        underscore_attrs_are_private = True

    stdout: str
    stderr: str
    exit_code: int
    error: Optional[str] = None
    raw: Optional[str] = Field(default=None, alias="_raw")


# new_version = Version(f"{tmpz.major}.{tmpz.minor}.{tmpz.micro+1}")
class SemanticVersion(Version):
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
