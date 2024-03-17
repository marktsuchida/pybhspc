# This file is part of pybhspc
# Copyright 2024 Board of Regents of the University of Wisconsin System
# SPDX-License-Identifier: MIT

cdef extern from "<Windows.h>":
    ctypedef unsigned int DWORD

    DWORD GetFileVersionInfoSizeA(const char *filename, DWORD *handle)

    bint GetFileVersionInfoA(
        const char *filename, DWORD handle, DWORD length, void *data
    )

    bint VerQueryValueA(
        const void *block, const char *sub_block, void *buffer, DWORD *length
    )

    ctypedef struct VS_FIXEDFILEINFO:
        DWORD dwFileVersionMS
        DWORD dwFileVersionLS
        DWORD dwProductVersionMS
        DWORD dwProductVersionLS
