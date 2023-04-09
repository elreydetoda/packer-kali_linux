from typing import Optional

from pydantic import Field
from pydantic.dataclasses import dataclass as py_dataclass


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
