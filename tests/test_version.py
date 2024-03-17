# This file is part of pybhspc
# Copyright 2024 Board of Regents of the University of Wisconsin System
# SPDX-License-Identifier: MIT

import ctypes
import sys

from bh_spc import _file_version, spcm_dll_version


def python_dll_filename():
    k32 = ctypes.WinDLL("kernel32")
    h_process = ctypes.c_void_p(k32.GetCurrentProcess())
    h_module = ctypes.c_void_p(sys.dllhandle)
    bufsiz = 1024
    buf = ctypes.create_string_buffer(bufsiz)
    # GetModuleFileNameExA() docs explain the name.
    k32.K32GetModuleFileNameExA(
        h_process, h_module, buf, ctypes.c_uint(bufsiz)
    )
    return buf.value


def test_python_dll_version():
    # Use the Python DLL as a specimen with known version number.
    v = _file_version.dll_file_version(python_dll_filename())
    assert v[0] == sys.version_info.major
    assert v[1] == sys.version_info.minor
    # The third number is not the Python micro version.


def test_spcm_dll_version():
    v = spcm_dll_version()
    # We don't have an easy way to get the correct value, but make sure the
    # numbers are in a reasonable range.
    assert v[0] >= 0
    assert v[1] >= 0
    assert v[2] >= 0
    assert v[3] >= 0
    assert v[0] < 100
    assert v[1] < 100
    assert v[2] < 100
    assert v[3] < 100
