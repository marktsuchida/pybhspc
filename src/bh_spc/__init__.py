# This file is part of pybhspc
# Copyright 2024 Board of Regents of the University of Wisconsin System
# SPDX-License-Identifier: MIT

# ruff: noqa: E402    # Module level import not at top of file
# ruff: noqa: TRY003  # Avoid specifying long messages outside exception class

"""
The root package of pybhspc.

Currently, low-level control is provided by the `spcm` module. Some utility
functions are provided here in the root package.
"""

__all__ = [
    "dump_module_state",
    "dump_state",
    "ini_file",
    "minimal_spcm_ini",
    "spcm",
    "spcm_dll_version",
]

import functools
import os
import os.path
import platform
import winreg

from ._file_version import dll_file_version as _dll_file_version

if platform.machine() != "AMD64":
    raise RuntimeError("Only supported on Windows x64")


@functools.cache
def _spcm_dll_dir() -> str:
    candidates = []
    try:
        with winreg.OpenKey(
            winreg.HKEY_CURRENT_USER, "SOFTWARE\\BH\\SPCM"
        ) as spcm_key:
            exe_path, _ = winreg.QueryValueEx(spcm_key, "FilePath")
        candidates.append(os.path.join(os.path.dirname(exe_path), "DLL"))
    except OSError:
        pass

    # Fallback in case registry key missing for some reason.
    fixed_dir = "C:/Program Files (x86)/BH/SPCM/DLL"
    if fixed_dir not in candidates:
        candidates.append(fixed_dir)

    for dll_dir in candidates:
        if os.path.isdir(dll_dir) and os.path.exists(
            os.path.join(dll_dir, "spcm64.dll")
        ):
            return dll_dir
    raise RuntimeError(
        f"Cannot find spcm64.dll in its expected install location (tried: {candidates})"
    )


@functools.cache
def spcm_dll_version() -> tuple[int, int, int, int]:
    """
    Return the file version number of the SPCM DLL.

    The information is read from the Windows version resource of the file.

    Returns
    -------
    tuple[int]
        File version number (a 4-tuple) of the spcm64.dll file.
    """
    return _dll_file_version(os.path.join(_spcm_dll_dir(), "spcm64.dll"))


# Reject ancient versions of the SPCM DLL. Structure layouts changed (and
# functions were added) in 4.00 (Apr 2014). Not actually tested with 4.00.
if spcm_dll_version() < (4, 0, 0, 0):
    vers = ".".join(str(n) for n in spcm_dll_version())
    raise RuntimeError(
        f"Minimum version of spcm64.dll supported is 4.0 (found: {vers})"
    )


with os.add_dll_directory(_spcm_dll_dir()):
    from . import spcm  # type: ignore[attr-defined]


# Imports that depend on spcm can now be done.
from ._dump_state import dump_module_state, dump_state
from ._ini_files import ini_file, minimal_spcm_ini
