# This file is part of pybhspc
# Copyright 2024 Board of Regents of the University of Wisconsin System
# SPDX-License-Identifier: MIT

__all__ = [
    "spcm",
    "spcm_dll_version",
    "minimal_spcm_ini",
    "ini_file",
    "dump_state",
]

import contextlib
import functools
import os
import os.path
import platform
import tempfile
import winreg
from typing import Iterator

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
    return _dll_file_version(os.path.join(_spcm_dll_dir(), "spcm64.dll"))


# Reject ancient versions of the SPCM DLL. Structure layouts changed (and
# functions were added) in 4.00 (Apr 2014). Not actually tested with 4.00.
if spcm_dll_version() < (4, 0, 0, 0):
    vers = ".".join(str(n) for n in spcm_dll_version())
    raise RuntimeError(
        f"Minimum version of spcm64.dll supported is 4.0 (found: {vers})"
    )


with os.add_dll_directory(_spcm_dll_dir()):
    from . import spcm  # type: ignore


def minimal_spcm_ini(mode: int = 0) -> str:
    """
    Return the text for a minimal .ini file for use with `spcm.init`.

    The generated .ini text does not set any of the device parameters, and
    attempts to initialize all available SPC modules.

    Parameters
    ----------
    mode : int
        The mode in which to initialize the SPCM DLL. Use 0 for hardware;
        special constants for simulation.

    Returns
    -------
    str
        The .ini text.
    """
    return f"""; SPCM
[spc_base]
simulation = {mode}
"""


@contextlib.contextmanager
def ini_file(text: str) -> Iterator[str]:
    """
    Context manager providing a temporary .ini file with the given text.

    Parameters
    ----------
    text : str
        The desired contents of the .ini file.

    Yields
    ------
    str
        The path name to the temporary .ini file.
    """
    with tempfile.TemporaryDirectory() as dirname:
        ininame = os.path.join(dirname, "pybhspc.ini")
        with open(ininame, mode="w") as inifile:
            inifile.write(text)
        yield ininame


def dump_state() -> None:
    """
    Print (to standard output) the status of all 8 SPC modules.

    This is a utility intended mostly for troubleshooting.
    """
    dll_mode = spcm.get_mode()
    print(f"DLL mode: {dll_mode}")

    for mod_no in range(8):
        try:
            info = spcm.get_module_info(mod_no)
        except RuntimeError as e:
            print(f"Module {mod_no}: Error: {e}")
            continue
        print(
            f"""Module {mod_no}:
    init status: {spcm.get_init_status(mod_no)}
    module info:
        module type: {info.module_type}   bus/slot number:  {info.bus_number}, {info.slot_number}
        in use: {info.in_use}   init:   {info.init}"""
        )
