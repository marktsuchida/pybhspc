# This file is part of pybhspc
# Copyright 2024 Board of Regents of the University of Wisconsin System
# SPDX-License-Identifier: MIT

# cython: language_level=3

import array
from enum import Enum
from collections.abc import Sequence

from cpython cimport array
from libc.string cimport memset, strlen

from . cimport _spcm


class SPCMError(RuntimeError):
    def __init__(self, code: int, message: str) -> None:
        super().__init__(message)
        self.code = code

    def __str__(self) -> str:
        return f"SPCM: {super().__str__()} ({self.code})"


class InitStatus(Enum):
    OK = 0
    NOT_DONE = -1
    WRONG_EEP_CHKSUM = -2
    WRONG_MOD_ID = -3
    HARD_TEST_ERR = -4
    CANT_OPEN_PCI_CARD = -5
    MOD_IN_USE = -6
    WINDRVR_VER = -7
    WRONG_LICENSE = -8
    FIRMWARE_VER = -9
    NO_LICENSE = -10
    LICENSE_NOT_VALID = -11
    LICENSE_DATE_EXP = -12
    CANT_OPEN_USB_CARD = -13
    XILINX_ERR = -100  # Including -1xx where xx is Xilinx error code.

    UNKNOWN = -999  # Not in SPCM DLL but in case we encounter something else.


def _make_init_status(code: int) -> InitStatus:
    try:
        return InitStatus(code)
    except ValueError:
        pass
    if code <= -100 and code > -200:
        return InitStatus.XILINX_ERR
    if code == -32:  # Module number out of range (attested).
        _raise_spcm_error(code)
    return InitStatus.UNKNOWN


class InUseStatus(Enum):
    NOT_IN_USE = 0
    IN_USE_HERE = 1
    IN_USE_ELSEWHERE = -1


cdef class ModInfo:
    cdef _spcm.SPCModInfo c_mod_info

    def __cinit__(self):
        memset(&self.c_mod_info, 0, sizeof(_spcm.SPCModInfo))

    @property
    def module_type(self) -> int:
        return self.c_mod_info.module_type

    @property
    def bus_number(self) -> int:
        return self.c_mod_info.bus_number

    @property
    def slot_number(self) -> int:
        return self.c_mod_info.slot_number

    @property
    def in_use(self) -> InUseStatus:
        return InUseStatus(self.c_mod_info.in_use)

    @property
    def init(self) -> InitStatus:
        return _make_init_status(self.c_mod_info.init)


def get_error_string(error_id: int) -> str:
    """
    Return the error message for the given SPCM error code.

    Parameters
    ----------
    error_id : int
        The error code

    Returns
    -------
    str
        The error message
    """
    cdef char[256] buf
    err = _spcm.SPC_get_error_string(error_id, buf, 256)
    if err != 0:
        return "Unknown SPCM error"
    s = (<bytes>buf[:strlen(buf)]).decode()
    # Capitalization is inconsistent, so normalize:
    if s and s[0].islower():
        s = s[0].capitalize() + s[1:]
    return s


def _raise_spcm_error(err: int) -> None:
    # SPC_close() should return 0 but in practice it seems to return a positive
    # value. Also all SPCM error codes are negative and some return values are
    # shared with positive codes that are not errors.
    if err < 0:
        raise SPCMError(err, f"{get_error_string(err)}")


def init(ini_file: bytes | str) -> None:
    """
    Initialize the SPCM DLL and one or all of the available SPC modules.

    Parameters
    ----------
    ini_file : bytes or str
        Filename of the .ini file used to specify parameters.

    Raises
    ------
    SPCMError
        If initialization fails or there were no available SPC modules.
    """
    if isinstance(ini_file, str):
        ini_file = ini_file.encode()
    _raise_spcm_error(_spcm.SPC_init(ini_file))


def close() -> None:
    """
    Uninitialize the SPCM DLL.

    Raises
    ------
    SPCMError
        If there was an error.
    """
    _raise_spcm_error(_spcm.SPC_close())


def get_init_status(mod_no: int) -> InitStatus:
    """
    Get the initialization status of the given SPC module.

    Parameters
    ----------
    mod_no : int
        The SPC module index.

    Returns
    -------
    InitStatus
        Whether the module is initialized, or the reason if not.
    """
    # Note return value is NOT an error code!
    return _make_init_status(_spcm.SPC_get_init_status(mod_no))


def get_mode() -> int:
    """
    Get the operation mode of the SPCM DLL.

    Returns
    -------
    int
        The mode: 0 for hardware control, or specific constants for simulation.

    Raises
    ------
    SPCMError
        If there was an error (e.g., if the DLL is not initialized).
    """
    ret = _spcm.SPC_get_mode()
    # Not mentioned in the docs, but the return value can be an error code.
    _raise_spcm_error(ret)
    return ret


def set_mode(mode: int, force_use: bool, use: Sequence[bool]) -> None:
    """
    Set the operation mode of the SPCM DLL and activate or deactivate each of
    the SPC modules.

    Parameters
    ----------
    mode : int
        The operation mode: 0 for hardware control, or specific constants for
        simulation.
    force_use : bool
        If true, try to obtain control of the requested modules even if they
        are in use by another process.
    use : sequence of bool
        Which SPC modules to activate. Currently up to 8 are supported. If
        fewer are given, the remaining modules will be deactivated.

    Raises
    ------
    SPCMError
        If there was an error or if no modules were activated.
    """
    # BH increased MAX_NO_OF_SPC from 8 to 32 in 2018 (SPCM DLL 4.4.1), and
    # SPC_set_mode() does indeed access 32 elements of 'use' (despite the
    # documentation still mentioning 8 modules).
    # Note that we always use 32 elements, which is safe for any (currently
    # known) version of the DLL. If the DLL only reads 8 elements, user code
    # will just get errors from other functions when trying to access the 9th
    # module and beyond.
    max_mods = 32
    if len(use) > max_mods:
        raise ValueError(f"No more than {max_mods} SPC modules are supported")
    cdef array.array u = array.array('i', (0,) * max_mods)
    for i, b in enumerate(use):
        u[i] = 1 if b else 0
    _raise_spcm_error(_spcm.SPC_set_mode(mode, force_use, u.data.as_ints))


def get_module_info(mod_no: int) -> ModInfo:
    """
    Get information about an SPC module.

    Parameters
    ----------
    mod_no : int
        The SPC module index.

    Returns
    -------
    ModInfo
        Basic information about the module.

    Riases
    ------
    SPCMError
        If there was an error.
    """
    cdef ModInfo mod_info = ModInfo()
    _raise_spcm_error(_spcm.SPC_get_module_info(mod_no, &mod_info.c_mod_info))
    return mod_info


def get_version(mod_no: int) -> str:
    """
    Get the FPGA version of an SPC module.

    Parameters
    ----------
    mod_no : int
        The SPC module index.

    Returns
    -------
    str
        The FPGA version (4 hex digits).

    Riases
    ------
    SPCMError
        If there was an error.
    """
    # SPC_get_version() is not fully documented but it is mentioned in the SPCM
    # DLL documentation as a method to check the FPGA version.
    # The version number is shown in hex in BH literature, so use unsigned
    # short.
    cdef unsigned short version = 0
    _raise_spcm_error(_spcm.SPC_get_version(mod_no, <short *>&version))
    return f"{version:X}"
