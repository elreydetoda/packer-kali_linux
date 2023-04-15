from pathlib import Path
from typing import Optional, Set, List

from pydantic import BaseModel
from pydantic.dataclasses import dataclass as py_dataclass

from models.misc import PydanticVersion


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
