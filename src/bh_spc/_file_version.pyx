# This file is part of pybhspc
# Copyright 2024 Board of Regents of the University of Wisconsin System
# SPDX-License-Identifier: MIT

# cython: language_level=3

from libc.stdlib cimport free, malloc

from . cimport _win32_version


cdef (int, int, int, int) _unpack_version_no(
    _win32_version.DWORD hi_dword, _win32_version.DWORD lo_dword
):
    return (
        hi_dword // 65536,
        hi_dword % 65536,
        lo_dword // 65536,
        lo_dword % 65536,
    )


def dll_file_version(filename: bytes | str) -> tuple[int, int, int, int]:
    if isinstance(filename, str):
        filename = filename.encode()
    cdef _win32_version.DWORD handle = 0
    ver_info_siz = _win32_version.GetFileVersionInfoSizeA(filename, &handle)
    if ver_info_siz == 0:
        raise RuntimeError(f"Cannot read version info size: {filename}")
    cdef void *data = malloc(ver_info_siz)
    if data is NULL:
        raise RuntimeError(f"Cannot allocate version info buffer")
    cdef _win32_version.VS_FIXEDFILEINFO *fixed_info = NULL
    cdef _win32_version.DWORD fixed_info_len = 0
    try:
        if not _win32_version.GetFileVersionInfoA(
            filename, handle, ver_info_siz, data
        ):
            raise RuntimeError(f"Cannor read version info: {filename}")
        if not _win32_version.VerQueryValueA(
            data, "\\", &fixed_info, &fixed_info_len
        ):
            raise RuntimeError(f"No fixed version info: {filename}")
        if fixed_info is NULL:
            raise RuntimeError(f"No fixed version info: {filename}")
        if fixed_info_len != sizeof(_win32_version.VS_FIXEDFILEINFO):
            raise AssertionError(
                f"Unexpected size of fixed version info: {filename}"
            )
        return _unpack_version_no(
            fixed_info.dwFileVersionMS, fixed_info.dwFileVersionLS
        )
    finally:
        free(data)
