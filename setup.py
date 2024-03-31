# This file is part of pybhspc
# Copyright 2024 Board of Regents of the University of Wisconsin System
# SPDX-License-Identifier: MIT

# ruff: noqa: TRY003  # Avoid specifying long messages outside exception class

"""Setup.py for pybhspc."""

import os.path
import platform

from Cython.Build import cythonize
from setuptools import Extension, setup

if platform.system() != "Windows":
    raise RuntimeError("Only supported on Windows")
if platform.machine() != "AMD64":
    raise RuntimeError("Only supported on Windows x64")

# Import winreg after check for Windows, so that error message is clearer.
import winreg


def _spcm_dll_dir() -> str:
    # This is (intentionally) simpler than the the runtime search, with no
    # fallbacks. It should be okay to assume that the installation behaves
    # predictably on the build machine.
    try:
        with winreg.OpenKey(
            winreg.HKEY_CURRENT_USER, "SOFTWARE\\BH\\SPCM"
        ) as spcm_key:
            exe_path, _ = winreg.QueryValueEx(spcm_key, "FilePath")
    except OSError as e:
        raise RuntimeError(
            "Failed to find SPCM install location in registry"
        ) from e
    ret = os.path.join(os.path.dirname(exe_path), "DLL")
    if not os.path.isdir(ret):
        raise RuntimeError(
            f"The SPCM-DLL install directory ({ret}) does not exist"
        )
    return ret


spcm_ext = Extension(
    "bh_spc.spcm",
    ["src/bh_spc/spcm.pyx"],
    include_dirs=[_spcm_dll_dir()],
    library_dirs=[os.path.join(_spcm_dll_dir(), "LIB/MSVC64")],
    libraries=["spcm64"],
)

file_version_ext = Extension(
    "bh_spc._file_version",
    ["src/bh_spc/_file_version.pyx"],
    libraries=["Version"],
)

setup(
    name="pybhspc",
    ext_modules=cythonize([spcm_ext, file_version_ext]),
    package_data={
        "bh_spc": ["*.pxd", "*.pyx"],
    },
)
