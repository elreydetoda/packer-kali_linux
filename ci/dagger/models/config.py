from pathlib import Path
from pydantic.dataclasses import dataclass as py_dataclass


@py_dataclass
class ConfigObj:
    base_path: Path
    git_root: Path
    config_data: dict
    lintrc_dir: Path
