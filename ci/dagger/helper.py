from pathlib import Path

from models.config import ConfigObj


def find(conf: ConfigObj, pattern: str):
    """
    Finds files based on the given pattern
    """
    paths = set(Path(conf.git_root).glob(f"**/{pattern}"))
    result = {
        # return the sanitized path
        path.resolve().relative_to(conf.git_root)
        # loop through all the results
        for path in paths
        # ensure they're not returning bento files or from .git/
        if ".git" not in str(path) and "bento" not in str(path)
    }
    return result
