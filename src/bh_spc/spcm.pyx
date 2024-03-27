# This file is part of pybhspc
# Copyright 2024 Board of Regents of the University of Wisconsin System
# SPDX-License-Identifier: MIT

# cython: language_level=3

"""
Low-level wrappers of the SPCM DLL functions and data structures.

This extension module aims to provide straightforward Python wrappers for the
C functions, structs, and enums in the SPCM DLL. Currently, only the functions
required to acquire data in FIFO mode are wrapped (excluding those that are
specific to the DPC-230).

Error codes returned by functions are converted to exceptions (SPCMError).
Functions that take output arguments are wrapped so that they provide the data
as a return value. A few other small changes are made to facilitate usage from
Python. In some cases enum names have been changed for readability.

A design goal of this module is to generally avoid artificially restricting
user code from performing operations that the C functions allow, even if they
are logically questionable or lead to unexpected return values. This is so that
this module can be used to experiment with the C API and discover its behavior.
A higher-level interface that guides the user toward correct usage can be built
on top of this module.

As such, to fully understand the correct usage of these functions and data
types, you will need to refer to the Becker-Hickl SPCM DLL documentation.
"""

import array
import dataclasses
import enum
from collections.abc import Iterable, Sequence
from typing import Any

from cpython cimport array
from libc.string cimport memcmp, memcpy, memset, strlen

from . cimport _spcm


class ErrorEnum(enum.Enum):
    """
    Enum of SPCM DLL error codes.

    The members' values are the SPCM DLL error codes (except for ``UNKNOWN``).
    An additional member, ``UNKNOWN``, which does not appear in the SPCM DLL,
    is used for any unknown error code that is encountered.

    Usually you will get a value of this type from the ``enum`` attribute of an
    `SPCMError` exception.

    Examples
    --------
    >>> for e in ErrorEnum:
    ...     print(e.value, e.name, get_error_string(e))
    0 NONE No error
    -1 OPEN_FILE Can't open file
    ...
    -32769 UNKNOWN Unknown SPCM error

    Print a list of all enum members and the corresponding error message.

    See Also
    --------
    SPCMError : Exception class for SPCM DLL errors.
    """

    NONE = 0
    OPEN_FILE = -1
    FILE_NVALID = -2
    MEM_ALLOC = -3
    READ_STR = -4
    WRONG_ID = -5
    EEP_CHKSUM = -6
    EEPROM_READ = -7
    EEPROM_WRITE = -8
    EEP_WR_DIS = -9
    BAD_PAR_ID = -10
    BAD_PAR_VAL = -11
    HARD_TEST = -12
    BAD_PARA1 = -13
    BAD_PARA2 = -14
    BAD_PARA3 = -15
    BAD_PARA4 = -16
    BAD_PARA5 = -17
    BAD_PARA6 = -18
    BAD_PARA7 = -19
    CANT_ARM = -20
    CANT_STOP = -21
    INV_REPT = -22
    NO_SEQ = -23
    SEQ_RUN = -24
    FILL_TOUT = -25
    BAD_FUNC = -26
    WINDRV_ERR = -27
    NOT_INIT = -28
    ERR_ID = -29
    RATES_NOT_RDY = -30
    NO_ACT_MOD = -31
    MOD_NO = -32
    NOT_ACTIVE = -33
    IN_USE = -34
    WINDRV_VER = -35
    DMA_ERR = -36
    WRONG_LICENSE = -37
    WRITE_STR = -38
    MAX_STREAM = -39
    XILINX_ERR = -40
    DET_NFOUND = -41
    FIRMWARE_VER = -42
    NO_LICENSE = -43
    LICENSE_NOT_VALID = -44
    LICENSE_DATE_EXP = -45
    DEEP_CHKSUM = -46
    DEEPROM_READ = -47
    DEEPROM_WRITE = -48
    RAM_BUSY = -49
    STR_TYPE = -50
    STR_SIZE = -51
    STR_BUF_NO = -52
    STR_NO_START = -53
    STR_NO_STOP = -54
    USBDRV_ERR = -55

    UNKNOWN = -32769  # Does not clash with 16-bit codes.

    @classmethod
    def _missing_(cls, value: int) -> ErrorEnum:
        return cls.UNKNOWN


class SPCMError(RuntimeError):
    """
    Exception raised when an SPCM function returns an error.

    Attributes
    ----------
    enum : ErrorEnum
        The error enum (read-only).
    code : int
        The raw error code, a negative value (read-only). This is usually
        redundant with the ``enum`` attribute but provided so that the code for
        an unknown (to pybhspc) error can be retrieved when ``enum`` is
        ``ErrorEnum.UNKNOWN``.

    See Also
    --------
    ErrorEnum : Enum of SPCM DLL error codes.
    """

    def __init__(self, code: int, message: str) -> None:
        super().__init__(message)
        self._code = code  # Preserves unknown codes.
        self._enum = ErrorEnum(code)

    def __str__(self) -> str:
        return f"SPCM: {super().__str__()} ({self.code})"

    @property
    def code(self) -> int:
        return self._code

    @property
    def enum(self) -> ErrorEnum:
        return self._enum


class DLLOperationMode(enum.Enum):
    """
    Enum for the operation mode of the SPCM DLL.

    Values of this type are returned by `get_mode` and are given to
    `set_mode`.

    Not to be confused with `ModuleType`, which has similar (but slightly
    different) values.

    Examples
    --------
    >>> for e in DLLOperationMode:
    ...     print(e.name, e.value)
    HARDWARE 0
    SIMULATE_SPC_600 600
    ...
    SIMULATE_SPC_150NX 152
    SIMULATE_SPC_150NXX 153
    ...

    Print a table of all the enum members.
    """

    HARDWARE = 0
    SIMULATE_SPC_600 = 600
    SIMULATE_SPC_630 = 630
    SIMULATE_SPC_700 = 700
    SIMULATE_SPC_730 = 730
    SIMULATE_SPC_130 = 130
    SIMULATE_SPC_830 = 830
    SIMULATE_SPC_140 = 140
    SIMULATE_SPC_930 = 930
    SIMULATE_DPC_230 = 230
    SIMULATE_SPC_150 = 150
    SIMULATE_SPC_150N = 151
    SIMULATE_SPC_150NX = 152
    SIMULATE_SPC_150NXX = 153
    SIMULATE_SPC_130EM = 131
    SIMULATE_SPC_130EMN = 132
    SIMULATE_SPC_130IN = 135
    SIMULATE_SPC_130INX = 136
    SIMULATE_SPC_130INXX = 137
    SIMULATE_SPC_160 = 160
    SIMULATE_SPC_160X = 161
    SIMULATE_SPC_160PCIE = 162
    SIMULATE_SPC_180N = 180
    SIMULATE_SPC_180NX = 181
    SIMULATE_SPC_180NXX = 182
    SIMULATE_SPC_QC_104 = 104
    SIMULATE_SPC_QC_004 = 4

    UNKNOWN = -32769  # Does not clash with 16-bit codes.

    @classmethod
    def _missing_(cls, value: int) -> DLLOperationMode:
        return cls.UNKNOWN


class InitStatus(enum.Enum):
    """
    Enum for the initialization status of an SPC module.

    Values of this type are returned by `get_init_status` and (as an attribute
    of `ModInfo`) by `get_module_info`.

    Examples
    --------
    >>> for e in InitStatus:
    ...     print(e.name, e.value)
    OK 0
    NOT_DONE -1
    ...
    XILINX_ERR -100

    Print a table of all the enum members.

    Notes
    -----
    The member `XILINX_ERR` is used for all possible Xilinx errors (-100
    through -199) returned by SPCM DLL functions.
    """

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
    XILINX_ERR = -100

    @classmethod
    def _missing_(cls, value: int) -> InitStatus:
        if -200 < value <= -100:
            return cls.XILINX_ERR


class InUseStatus(enum.Enum):
    """
    Enum representing whether an SPC module is in use.

    Possible values are `NOT_IN_USE` (0), `IN_USE_HERE` (1), and
    `IN_USE_ELSEWHERE` (-1), "elsewhere" meaning by another program or process.

    Values of this type are returned (as an attribute of `ModInfo`) by
    `get_module_info`.
    """

    NOT_IN_USE = 0
    IN_USE_HERE = 1
    IN_USE_ELSEWHERE = -1


class ModuleType(enum.Enum):
    """
    Enum for the module type (model number) of an SPC module.

    Values of this type are returned by `test_id` and (as an attribute of
    `ModInfo`) by `get_module_info`.

    Not to be confused with `DLLOperationMode`, which has similar (but slightly
    different) values.

    Examples
    --------
    >>> for e in ModuleType:
    ...     print(e.name, e.value)
    SPC_600 600
    SPC_630 630
    ...
    SPC_150NX_OR_150NXX 152
    ...

    Print a table of all the enum members.
    """

    SPC_600 = 600
    SPC_630 = 630
    SPC_700 = 700
    SPC_730 = 730
    SPC_130 = 130
    SPC_830 = 830
    SPC_140 = 140
    SPC_930 = 930
    DPC_230 = 230
    SPC_150 = 150
    SPC_150N = 151
    SPC_150NX_OR_150NXX = 152
    SPC_130EM = 131
    SPC_130EMN = 132
    SPC_130IN = 135
    SPC_130INX = 136
    SPC_130INXX = 137
    SPC_160 = 160
    SPC_160X = 161
    SPC_160PCIE = 162
    SPC_180N = 180
    SPC_180NX = 181
    SPC_180NXX = 182
    SPC_QC_104 = 104
    SPC_QC_004 = 4

    UNKNOWN = 0

    @classmethod
    def _missing_(cls, value: int) -> ModuleType:
        return cls.UNKNOWN


cdef class ModInfo:
    """
    SPC module information.

    Wraps the SPCM DLL ``SPCModInfo`` struct. Values of this type are returned
    by `get_module_info`.

    Attributes
    ----------
    module_type : ModuleType
        The module type (read-only).
    bus_number : int
        The PCI bus number (read-only).
    slot_number : int
        The PCI slot number (read-only).
    in_use : InUseStatus
        Whether the module is in use (read-only).
    init : InitStatus
        Whether the module is initialized, and the reason why if not
        (read-only).
    """

    cdef _spcm.SPCModInfo c

    def __cinit__(self) -> None:
        memset(&self.c, 0, sizeof(_spcm.SPCModInfo))

    def __repr__(self) -> str:
        return "<ModInfo({})>".format(
            ", ".join(f"{f}={repr(getattr(self, f))}" for f in self._fields)
        )

    def items(self) -> Iterable[tuple[str, Any]]:
        """
        Return an iterable yielding the fields and values in fixed order.

        Returns
        -------
        Iterable
            An iterable yielding the pair (name, value) for every field.
        """
        return ((f, getattr(self, f)) for f in self._fields)

    def as_dict(self) -> dict[str, Any]:
        """
        Return a dictionary containing the fields and values.

        Returns
        -------
        dict
            Every field and its value.
        """
        return dict(self.items())

    _fields = (
        "module_type",
        "bus_number",
        "slot_number",
        "in_use",
        "init",
    )

    @property
    def module_type(self) -> ModuleType:
        return ModuleType(self.c.module_type)

    @property
    def bus_number(self) -> int:
        return self.c.bus_number

    @property
    def slot_number(self) -> int:
        return self.c.slot_number

    @property
    def in_use(self) -> InUseStatus:
        return InUseStatus(self.c.in_use)

    @property
    def init(self) -> InitStatus:
        return InitStatus(self.c.init)

    # Leave out base_adr. It is not valid on 64-bit.


class ParID(enum.Enum):
    """
    Enum of SPC parameter ids.

    The members' values are the SPCM DLL parameter ids. Members also have an
    attribute `type` which is either `int` or `float`.

    Values of this type are passed to `get_parameter` and `set_parameter`. The
    attributes of the `Data` class match the lowercased version of the enum
    member names.

    C language parameter types ``short``, ``unsigned short``, and ``unsigned
    long`` all map to Python `int`. C language ``float`` maps to Python
    ``float``.

    Attributes
    ----------
    type : type
        The parameter type: `int` or `float`.

    Examples
    --------
    >>> for e in ParID:
    ...     print(e.value, e.name, e.type.__name__)
    0 CFD_LIMIT_LOW float
    1 CFD_LIMIT_HIGH float
    ...
    27 MODE int
    ...

    Print a list of all parameter ids, their names, and types.

    See Also
    --------
    Data : Aggregate object of all the parameters and their values.
    """

    CFD_LIMIT_LOW = (0, float)
    CFD_LIMIT_HIGH = (1, float)
    CFD_ZC_LEVEL = (2, float)
    CFD_HOLDOFF = (3, float)
    SYNC_ZC_LEVEL = (4, float)
    SYNC_FREQ_DIV = (5, int)
    SYNC_HOLDOFF = (6, float)
    SYNC_THRESHOLD = (7, float)
    TAC_RANGE = (8, float)
    TAC_GAIN = (9, int)
    TAC_OFFSET = (10, float)
    TAC_LIMIT_LOW = (11, float)
    TAC_LIMIT_HIGH = (12, float)
    ADC_RESOLUTION = (13, int)
    EXT_LATCH_DELAY = (14, int)
    COLLECT_TIME = (15, float)
    DISPLAY_TIME = (16, float)
    REPEAT_TIME = (17, float)
    STOP_ON_TIME = (18, int)
    STOP_ON_OVFL = (19, int)
    DITHER_RANGE = (20, int)
    COUNT_INCR = (21, int)
    MEM_BANK = (22, int)
    DEAD_TIME_COMP = (23, int)
    SCAN_CONTROL = (24, int)
    ROUTING_MODE = (25, int)
    TAC_ENABLE_HOLD = (26, float)
    MODE = (27, int)
    SCAN_SIZE_X = (28, int)
    SCAN_SIZE_Y = (29, int)
    SCAN_ROUT_X = (30, int)
    SCAN_ROUT_Y = (31, int)
    SCAN_POLARITY = (32, int)
    SCAN_FLYBACK = (33, int)
    SCAN_BORDERS = (34, int)
    PIXEL_TIME = (35, float)
    PIXEL_CLOCK = (36, int)
    LINE_COMPRESSION = (37, int)
    TRIGGER = (38, int)
    EXT_PIXCLK_DIV = (39, int)
    RATE_COUNT_TIME = (40, float)
    MACRO_TIME_CLK = (41, int)
    ADD_SELECT = (42, int)
    ADC_ZOOM = (43, int)
    XY_GAIN = (44, int)
    IMG_SIZE_X = (45, int)
    IMG_SIZE_Y = (46, int)
    IMG_ROUT_X = (47, int)
    IMG_ROUT_Y = (48, int)
    MASTER_CLOCK = (49, int)
    ADC_SAMPLE_DELAY = (50, int)
    DETECTOR_TYPE = (51, int)
    TDC_CONTROL = (52, int)
    CHAN_ENABLE = (53, int)
    CHAN_SLOPE = (54, int)
    CHAN_SPEC_NO = (55, int)
    TDC_OFFSET1 = (56, float)
    TDC_OFFSET2 = (57, float)
    TDC_OFFSET3 = (58, float)
    TDC_OFFSET4 = (59, float)

    def __new__(cls, value: int, typ: type) -> None:
        obj = object.__new__(cls)
        obj._value_ = value
        obj._type = typ
        return obj

    @property
    def type(self) -> type:
        return self._type


# For use in defining Data struct fields.
_params = tuple(p.name.lower() for p in ParID)


cdef class Data:
    """
    The collection of values for all SPC parameters.

    Wraps the SPCM DLL ``SPCdata`` struct. Values of this type are returned by
    `get_parameters` and are passed to `set_parameters`.

    Instances have attributes that match the `ParID` enum member names, but in
    lowercase. Attribute types match the `type` attribute of the corresponding
    `ParID` enum member.

    An instance created by calling ``Data()`` contains zero for every
    parameter.

    Instances can be duplicated using ``copy.copy()`` (or ``copy.deepcopy()``),
    and can also be compared with ``==`` for (exact) equality (see Notes
    below).

    Examples
    --------
    >>> for p, v in Data().items():
    ...     print(f"{p} = {v}")
    cfd_limit_low = 0.0
    cfd_limit_high = 0.0
    ...
    mode = 0
    ...

    Print the values of all parameters of a default instance (more interesting
    if you replace ``Data()`` with, say, ``get_parameters(0)``).

    See Also
    --------
    ParID : Enum of SPC parameter ids.

    Notes
    -----
    The C struct fields ``base_adr``, ``init``, ``pci_card_no``, and
    ``test_eep`` are hidden from this Python wrapper. These fields are either
    not currently meaningful or are redundant with information that can be
    obtained from `get_module_info` or `get_eeprom_data`. However, these fields
    are included in the equality comparison, so an instance created as
    ``Data()`` may never compare equal to an instance returned by
    `get_parameters` even if all attributes are set to be equal. Usually it is
    best to avoid creating an instance from scratch except in special
    situations such as testing. Always obtain an instance from
    `get_parameters`.
    """

    # We shouldn't hit this assertion because the build should have failed (due
    # to missing struct fields) if old headers (SPCM DLL < 5.1) were used. This
    # is mostly to document our assumption (and report any unexpected changes
    # in the future).
    assert sizeof(_spcm.SPCdata) == 256, \
        "sizeof(SPCdata) (at build time) should have been 256"

    cdef _spcm.SPCdata c

    def __cinit__(self) -> None:
        memset(&self.c, 0, sizeof(_spcm.SPCdata))

    def __copy__(self) -> Data:
        cdef Data cpy = Data()
        memcpy(&cpy.c, &self.c, sizeof(_spcm.SPCdata))
        return cpy

    def __deepcopy__(self, memo: Any) -> Data:
        # There are no objects stored by reference.
        return self.__copy__()

    def __eq__(self, other: Any) -> bool:
        if type(other) is not type(self):
            return False
        cdef Data o = other
        # There will be some irregular behavior when the unexposed parts of the
        # struct (base_addr, init, pci_card_no, and reserve) are not equal. But
        # this should not cause problems because their values should be
        # consistent if the SPCdata was originally obtained from
        # SPC_get_parameters() after zero-initialization.
        return memcmp(&o.c, &self.c, sizeof(_spcm.SPCdata)) == 0

    def __repr__(self) -> str:
        return "<Data({})>".format(
            ", ".join(
                f"{f}={repr(getattr(self, f))}" for f in self._fields
            )
        )

    def items(self) -> Iterable[tuple[str, int | float]]:
        """
        Return an iterable yielding the fields and values in fixed order.

        The order matches with the `ParID` enum members.

        Returns
        -------
        Iterable
            An iterable yielding the pair (name, value) for every field.
        """
        return ((f, getattr(self, f)) for f in self._fields)

    def as_dict(self) -> dict[str, int | float]:
        """
        Return a dictionary containing the fields and values.

        Returns
        -------
        dict
            Every field and its value.
        """
        return dict(self.items())

    def diff_items(self, other: Data) -> Iterable[tuple[str, int | float]]:
        """
        Return an iterable yielding the fields and values where they differ
        from the given other instance, in fixed order.

        The order matches with the `ParID` enum members.

        Returns
        -------
        Iterable
            An iterable yielding the pair (name, value) for every field in this
            instance where the value differs from the other instance.
        """
        return (
            (f, getattr(self, f))
            for f in self._fields
            if getattr(self, f) != getattr(other, f)
        )

    def diff_as_dict(self, other: Data) -> dict[str, int | float]:
        """
        Return a dictionary containing the fields and their values where they
        differ from the given other instance.

        Parameters
        ----------
        other : Data
            The instance to compare to.

        Returns
        -------
        dict
            Every field that differs from ``other`` and its value in this
            instance where the value differs from the other instance.
        """
        return dict(self.diff_items(other))

    # Here we order the fields so that they match the ParID enum, _not_ the
    # order they appear in the C struct. Not only does this hide the
    # superficial inconsistency, but it also puts the fields in a more logical
    # order, probably because the ParID order is the original order (the struct
    # fields were reordered in SPCM DLL 4.0).

    # (I would love to avoid writing out the getter and setter for every field,
    # but cannot think of a way to do so, other than nasty external codegen.
    # There may be ways to make it a little DRYer, but we cannot eliminate the
    # mapping of Python attributes to C struct fields. For now let's keep them
    # all uniform and make sure to use editor macros to make any changes
    # uniform (except for the tdc_offset array fields).)

    _fields = _params

    @property
    def cfd_limit_low(self) -> float:
        return self.c.cfd_limit_low

    @cfd_limit_low.setter
    def cfd_limit_low(self, v: float) -> None:
        self.c.cfd_limit_low = <float>v

    @property
    def cfd_limit_high(self) -> float:
        return self.c.cfd_limit_high

    @cfd_limit_high.setter
    def cfd_limit_high(self, v: float) -> None:
        self.c.cfd_limit_high = <float>v

    @property
    def cfd_zc_level(self) -> float:
        return self.c.cfd_zc_level

    @cfd_zc_level.setter
    def cfd_zc_level(self, v: float) -> None:
        self.c.cfd_zc_level = <float>v

    @property
    def cfd_holdoff(self) -> float:
        return self.c.cfd_holdoff

    @cfd_holdoff.setter
    def cfd_holdoff(self, v: float) -> None:
        self.c.cfd_holdoff = <float>v

    @property
    def sync_zc_level(self) -> float:
        return self.c.sync_zc_level

    @sync_zc_level.setter
    def sync_zc_level(self, v: float) -> None:
        self.c.sync_zc_level = <float>v

    @property
    def sync_freq_div(self) -> int:
        return self.c.sync_freq_div

    @sync_freq_div.setter
    def sync_freq_div(self, v: int) -> None:
        self.c.sync_freq_div = v

    @property
    def sync_holdoff(self) -> float:
        return self.c.sync_holdoff

    @sync_holdoff.setter
    def sync_holdoff(self, v: float) -> None:
        self.c.sync_holdoff = <float>v

    @property
    def sync_threshold(self) -> float:
        return self.c.sync_threshold

    @sync_threshold.setter
    def sync_threshold(self, v: float) -> None:
        self.c.sync_threshold = <float>v

    @property
    def tac_range(self) -> float:
        return self.c.tac_range

    @tac_range.setter
    def tac_range(self, v: float) -> None:
        self.c.tac_range = <float>v

    @property
    def tac_gain(self) -> int:
        return self.c.tac_gain

    @tac_gain.setter
    def tac_gain(self, v: int) -> None:
        self.c.tac_gain = v

    @property
    def tac_offset(self) -> float:
        return self.c.tac_offset

    @tac_offset.setter
    def tac_offset(self, v: float) -> None:
        self.c.tac_offset = <float>v

    @property
    def tac_limit_low(self) -> float:
        return self.c.tac_limit_low

    @tac_limit_low.setter
    def tac_limit_low(self, v: float) -> None:
        self.c.tac_limit_low = <float>v

    @property
    def tac_limit_high(self) -> float:
        return self.c.tac_limit_high

    @tac_limit_high.setter
    def tac_limit_high(self, v: float) -> None:
        self.c.tac_limit_high = <float>v

    @property
    def adc_resolution(self) -> int:
        return self.c.adc_resolution

    @adc_resolution.setter
    def adc_resolution(self, v: int) -> None:
        self.c.adc_resolution = v

    @property
    def ext_latch_delay(self) -> int:
        return self.c.ext_latch_delay

    @ext_latch_delay.setter
    def ext_latch_delay(self, v: int) -> None:
        self.c.ext_latch_delay = v

    @property
    def collect_time(self) -> float:
        return self.c.collect_time

    @collect_time.setter
    def collect_time(self, v: float) -> None:
        self.c.collect_time = <float>v

    @property
    def display_time(self) -> float:
        return self.c.display_time

    @display_time.setter
    def display_time(self, v: float) -> None:
        self.c.display_time = <float>v

    @property
    def repeat_time(self) -> float:
        return self.c.repeat_time

    @repeat_time.setter
    def repeat_time(self, v: float) -> None:
        self.c.repeat_time = <float>v

    @property
    def stop_on_time(self) -> int:
        return self.c.stop_on_time

    @stop_on_time.setter
    def stop_on_time(self, v: int) -> None:
        self.c.stop_on_time = v

    @property
    def stop_on_ovfl(self) -> int:
        return self.c.stop_on_ovfl

    @stop_on_ovfl.setter
    def stop_on_ovfl(self, v: int) -> None:
        self.c.stop_on_ovfl = v

    @property
    def dither_range(self) -> int:
        return self.c.dither_range

    @dither_range.setter
    def dither_range(self, v: int) -> None:
        self.c.dither_range = v

    @property
    def count_incr(self) -> int:
        return self.c.count_incr

    @count_incr.setter
    def count_incr(self, v: int) -> None:
        self.c.count_incr = v

    @property
    def mem_bank(self) -> int:
        return self.c.mem_bank

    @mem_bank.setter
    def mem_bank(self, v: int) -> None:
        self.c.mem_bank = v

    @property
    def dead_time_comp(self) -> int:
        return self.c.dead_time_comp

    @dead_time_comp.setter
    def dead_time_comp(self, v: int) -> None:
        self.c.dead_time_comp = v

    @property
    def scan_control(self) -> int:
        return self.c.scan_control

    @scan_control.setter
    def scan_control(self, v: int) -> None:
        self.c.scan_control = v

    @property
    def routing_mode(self) -> int:
        return self.c.routing_mode

    @routing_mode.setter
    def routing_mode(self, v: int) -> None:
        self.c.routing_mode = v

    @property
    def tac_enable_hold(self) -> float:
        return self.c.tac_enable_hold

    @tac_enable_hold.setter
    def tac_enable_hold(self, v: float) -> None:
        self.c.tac_enable_hold = <float>v

    @property
    def mode(self) -> int:
        return self.c.mode

    @mode.setter
    def mode(self, v: int) -> None:
        self.c.mode = v

    @property
    def scan_size_x(self) -> int:
        return self.c.scan_size_x

    @scan_size_x.setter
    def scan_size_x(self, v: int) -> None:
        self.c.scan_size_x = v

    @property
    def scan_size_y(self) -> int:
        return self.c.scan_size_y

    @scan_size_y.setter
    def scan_size_y(self, v: int) -> None:
        self.c.scan_size_y = v

    @property
    def scan_rout_x(self) -> int:
        return self.c.scan_rout_x

    @scan_rout_x.setter
    def scan_rout_x(self, v: int) -> None:
        self.c.scan_rout_x = v

    @property
    def scan_rout_y(self) -> int:
        return self.c.scan_rout_y

    @scan_rout_y.setter
    def scan_rout_y(self, v: int) -> None:
        self.c.scan_rout_y = v

    @property
    def scan_polarity(self) -> int:
        return self.c.scan_polarity

    @scan_polarity.setter
    def scan_polarity(self, v: int) -> None:
        self.c.scan_polarity = v

    @property
    def scan_flyback(self) -> int:
        return self.c.scan_flyback

    @scan_flyback.setter
    def scan_flyback(self, v: int) -> None:
        self.c.scan_flyback = v

    @property
    def scan_borders(self) -> int:
        return self.c.scan_borders

    @scan_borders.setter
    def scan_borders(self, v: int) -> None:
        self.c.scan_borders = v

    @property
    def pixel_time(self) -> float:
        return self.c.pixel_time

    @pixel_time.setter
    def pixel_time(self, v: float) -> None:
        self.c.pixel_time = <float>v

    @property
    def pixel_clock(self) -> int:
        return self.c.pixel_clock

    @pixel_clock.setter
    def pixel_clock(self, v: int) -> None:
        self.c.pixel_clock = v

    @property
    def line_compression(self) -> int:
        return self.c.line_compression

    @line_compression.setter
    def line_compression(self, v: int) -> None:
        self.c.line_compression = v

    @property
    def trigger(self) -> int:
        return self.c.trigger

    @trigger.setter
    def trigger(self, v: int) -> None:
        self.c.trigger = v

    @property
    def ext_pixclk_div(self) -> int:
        return self.c.ext_pixclk_div

    @ext_pixclk_div.setter
    def ext_pixclk_div(self, v: int) -> None:
        self.c.ext_pixclk_div = v

    @property
    def rate_count_time(self) -> float:
        return self.c.rate_count_time

    @rate_count_time.setter
    def rate_count_time(self, v: float) -> None:
        self.c.rate_count_time = <float>v

    @property
    def macro_time_clk(self) -> int:
        return self.c.macro_time_clk

    @macro_time_clk.setter
    def macro_time_clk(self, v: int) -> None:
        self.c.macro_time_clk = v

    @property
    def add_select(self) -> int:
        return self.c.add_select

    @add_select.setter
    def add_select(self, v: int) -> None:
        self.c.add_select = v

    @property
    def adc_zoom(self) -> int:
        return self.c.adc_zoom

    @adc_zoom.setter
    def adc_zoom(self, v: int) -> None:
        self.c.adc_zoom = v

    @property
    def xy_gain(self) -> int:
        return self.c.xy_gain

    @xy_gain.setter
    def xy_gain(self, v: int) -> None:
        self.c.xy_gain = v

    @property
    def img_size_x(self) -> int:
        return self.c.img_size_x

    @img_size_x.setter
    def img_size_x(self, v: int) -> None:
        self.c.img_size_x = v

    @property
    def img_size_y(self) -> int:
        return self.c.img_size_y

    @img_size_y.setter
    def img_size_y(self, v: int) -> None:
        self.c.img_size_y = v

    @property
    def img_rout_x(self) -> int:
        return self.c.img_rout_x

    @img_rout_x.setter
    def img_rout_x(self, v: int) -> None:
        self.c.img_rout_x = v

    @property
    def img_rout_y(self) -> int:
        return self.c.img_rout_y

    @img_rout_y.setter
    def img_rout_y(self, v: int) -> None:
        self.c.img_rout_y = v

    @property
    def master_clock(self) -> int:
        return self.c.master_clock

    @master_clock.setter
    def master_clock(self, v: int) -> None:
        self.c.master_clock = v

    @property
    def adc_sample_delay(self) -> int:
        return self.c.adc_sample_delay

    @adc_sample_delay.setter
    def adc_sample_delay(self, v: int) -> None:
        self.c.adc_sample_delay = v

    @property
    def detector_type(self) -> int:
        return self.c.detector_type

    @detector_type.setter
    def detector_type(self, v: int) -> None:
        self.c.detector_type = v

    @property
    def tdc_control(self) -> int:
        return self.c.tdc_control

    @tdc_control.setter
    def tdc_control(self, v: int) -> None:
        self.c.tdc_control = v

    @property
    def chan_enable(self) -> int:
        return self.c.chan_enable

    @chan_enable.setter
    def chan_enable(self, v: int) -> None:
        self.c.chan_enable = v

    @property
    def chan_slope(self) -> int:
        return self.c.chan_slope

    @chan_slope.setter
    def chan_slope(self, v: int) -> None:
        self.c.chan_slope = v

    @property
    def chan_spec_no(self) -> int:
        return self.c.chan_spec_no

    @chan_spec_no.setter
    def chan_spec_no(self, v: int) -> None:
        self.c.chan_spec_no = v

    # Hide the float[4] tdc_offset and expose properties that match the ParID
    # and INI fields exactly. This has the added advantage that, should BH
    # increase the size from 4 in the future, no API change will be required.

    @property
    def tdc_offset1(self) -> int:
        return self.c.tdc_offset[0]

    @tdc_offset1.setter
    def tdc_offset1(self, v: int) -> None:
        self.c.tdc_offset[0] = v

    @property
    def tdc_offset2(self) -> int:
        return self.c.tdc_offset[1]

    @tdc_offset2.setter
    def tdc_offset2(self, v: int) -> None:
        self.c.tdc_offset[1] = v

    @property
    def tdc_offset3(self) -> int:
        return self.c.tdc_offset[2]

    @tdc_offset3.setter
    def tdc_offset3(self, v: int) -> None:
        self.c.tdc_offset[2] = v

    @property
    def tdc_offset4(self) -> int:
        return self.c.tdc_offset[3]

    @tdc_offset4.setter
    def tdc_offset4(self, v: int) -> None:
        self.c.tdc_offset[3] = v


cdef class AdjustPara:
    """
    Adjustment parameters (wraps the ``SPC_Adjust_Para`` struct).

    Wraps the SPCM DLL ``SPC_Adjust_Para`` struct. Values of this type are
    returned by `get_adjust_parameters` and (as an attribute of `EEPData`) by
    `get_eeprom_data`.

    Instances have the attributes corresponding to the C struct fields. All are
    read-only.
    """

    cdef _spcm.SPC_Adjust_Para c

    def __cinit__(self) -> None:
        memset(&self.c, 0, sizeof(_spcm.SPC_Adjust_Para))

    def __repr__(self) -> str:
        return "<AdjustPara({})>".format(
            ", ".join(f"{f}={repr(getattr(self, f))}" for f in self._fields)
        )

    def items(self) -> Iterable[tuple[str, int | float]]:
        """
        Return an iterable yielding the fields and values in fixed order.

        Returns
        -------
        Iterable
            An iterable yielding the pair (name, value) for every field.
        """
        return ((f, getattr(self, f)) for f in self._fields)

    def as_dict(self) -> dict[str, int | float]:
        """
        Return a dictionary containing the fields and values.

        Returns
        -------
        dict
            Every field and its value.
        """
        return dict(self.items())

    _fields = (
        "vrt1",
        "vrt2",
        "vrt3",
        "dith_g",
        "gain_1",
        "gain_2",
        "gain_4",
        "gain_8",
        "tac_r0",
        "tac_r1",
        "tac_r2",
        "tac_r4",
        "tac_r8",
        "sync_div",
    )

    @property
    def vrt1(self) -> int:
        return self.c.vrt1

    @property
    def vrt2(self) -> int:
        return self.c.vrt2

    @property
    def vrt3(self) -> int:
        return self.c.vrt3

    @property
    def dith_g(self) -> int:
        return self.c.dith_g

    @property
    def gain_1(self) -> float:
        return self.c.gain_1

    @property
    def gain_2(self) -> float:
        return self.c.gain_2

    @property
    def gain_4(self) -> float:
        return self.c.gain_4

    @property
    def gain_8(self) -> float:
        return self.c.gain_8

    @property
    def tac_r0(self) -> float:
        return self.c.tac_r0

    @property
    def tac_r1(self) -> float:
        return self.c.tac_r1

    @property
    def tac_r2(self) -> float:
        return self.c.tac_r2

    @property
    def tac_r4(self) -> float:
        return self.c.tac_r4

    @property
    def tac_r8(self) -> float:
        return self.c.tac_r8

    @property
    def sync_div(self) -> int:
        return self.c.sync_div


cdef class EEPData:
    """
    Information read from an SPC modules non-volatile memory.

    Wraps the SPCM DLL ``SPC_EEP_Data`` struct. Values of this type are
    returned by `get_eeprom_data`.

    Attributes
    ----------
    module_type : str
        The module type as a string, such as ``"SPC-180NX"`` (read-only).
    serial_no : str
        The serial number (read-only).
    date : str
        Production date, such as ``"2024-03-26"`` (read-only).
    adj_para : AdjustPara
        Adjustment parameters (read-only).
    """

    cdef _spcm.SPC_EEP_Data c

    def __cinit__(self) -> None:
        memset(&self.c, 0, sizeof(_spcm.SPC_EEP_Data))

    def __repr__(self) -> str:
        return "<EEPData({})>".format(
            ", ".join(f"{f}={repr(getattr(self, f))}" for f in self._fields)
        )

    def items(self) -> Iterable[tuple[str, Any]]:
        """
        Return an iterable yielding the fields and values in fixed order.

        Returns
        -------
        Iterable
            An iterable yielding the pair (name, value) for every field.
        """
        return ((f, getattr(self, f)) for f in self._fields)

    def as_dict(self) -> dict[str, Any]:
        """
        Return a dictionary containing the fields and values.

        Returns
        -------
        dict
            Every field and its value.
        """
        return dict(self.items())

    _fields = (
        "module_type",
        "serial_no",
        "date",
        "adj_para",
    )

    @property
    def module_type(self) -> str:
        return self.c.module_type.decode('ascii')

    @property
    def serial_no(self) -> str:
        return self.c.serial_no.decode('ascii')

    @property
    def date(self) -> str:
        return self.c.date.decode('ascii')

    @property
    def adj_para(self) -> AdjustPara:
        cdef AdjustPara ret = AdjustPara()
        memcpy(&ret.c, &self.c.adj_para, sizeof(_spcm.SPC_Adjust_Para))
        return ret


cdef class RateValues:
    """
    Rate counter values.

    Wraps the SPCM DLL ``rate_values`` struct. Values of this type are returned
    by `read_rates`.

    Attributes
    ----------
    sync_rate : float
        The SYNC rate (counts/s, read-only).
    cfd_rate : float
        The CFD rate (counts/s, read-only).
    tac_rate : float
        The TAC rate (counts/s, read-only).
    adc_rate : float
        The ADC rate (counts/s, read-only).
    """

    cdef _spcm.rate_values c

    def __cinit__(self) -> None:
        memset(&self.c, 0, sizeof(_spcm.rate_values))

    def __repr__(self) -> str:
        return "<RateValues({})>".format(
            ", ".join(f"{f}={repr(getattr(self, f))}" for f in self._fields)
        )

    def items(self) -> Iterable[tuple[str, float]]:
        """
        Return an iterable yielding the fields and values in fixed order.

        Returns
        -------
        Iterable
            An iterable yielding the pair (name, value) for every field.
        """
        return ((f, getattr(self, f)) for f in self._fields)

    def as_dict(self) -> dict[str, float]:
        """
        Return a dictionary containing the fields and values.

        Returns
        -------
        dict
            Every field and its value.
        """
        return dict(self.items())

    _fields = (
        "sync_rate",
        "cfd_rate",
        "tac_rate",
        "adc_rate",
    )

    @property
    def sync_rate(self) -> float:
        return self.c.sync_rate

    @property
    def cfd_rate(self) -> float:
        return self.c.cfd_rate

    @property
    def tac_rate(self) -> float:
        return self.c.tac_rate

    @property
    def adc_rate(self) -> float:
        return self.c.adc_rate


class MeasurementState(enum.Flag):
    """
    Flag enum for measurement state.

    Values of this type are returned by `test_state`.

    For the sake of readability, the enum members are named differently from
    the SPCM DLL. See the example below for how to view the correspondence.

    Examples
    --------
    >>> for n in MeasurementState.__members__:
    ...     e = MeasurementState[n]
    ...     print(e.name, e.value)
    STOPPED_ON_OVERFLOW 1
    OVERFLOW 2
    ...

    Print a table of all enum members, including aliases.

    >>> for n in MeasurementState.__members__:
    ...     e = MeasurementState[n]
    ...     print(
    ...         f"{measurement_state_bh_name(e.name):16} {e.value: 6} {e.name}"
    ...     )
    SPC_OVERFL            1 STOPPED_ON_OVERFLOW
    SPC_OVERFLOW          2 OVERFLOW
    SPC_TIME_OVER         4 STOPPED_ON_COLLECT_TIME
    SPC_COLTIM_OVER       8 COLLECT_TIME_ELAPSED
    SPC_CMD_STOP         16 STOPPED_ON_COMMAND
    SPC_REPTIM_OVER      32 REPEAT_TIME_ELAPSED
    SPC_ARMED           128 ARMED
    SPC_COLTIM_2OVER    256 COLLECT_TIME_ELAPSED_2ND_TIME
    SPC_REPTIM_2OVER    512 REPEAT_TIME_ELAPSED_2ND_TIME
    SPC_FOVFL          1024 FIFO_OVERFLOW
    SPC_FEMPTY         2048 FIFO_EMPTY
    SPC_WAIT_FR        8192 WAITING_FOR_FRAME
    SPC_MEASURE          64 MEASUREMENT_ACTIVE
    SPC_FOVFL          1024 FIFO_OVERFLOW
    SPC_FEMPTY         2048 FIFO_EMPTY
    SPC_WAIT_TRG       4096 WAITING_FOR_TRIGGER
    SPC_HFILL_NRDY    32768 HARDWARE_FILL_NOT_READY
    SPC_SEQ_STOP      16384 STOPPED_BY_SEQUENCER
    SPC_WAIT_FR        8192 WAITING_FOR_FRAME
    SPC_MEASURE          64 MEASUREMENT_ACTIVE
    SPC_ARMED           128 ARMED
    SPC_COLTIM_OVER       8 COLLECT_TIME_ELAPSED
    SPC_COLTIM_2OVER    256 COLLECT_TIME_ELAPSED_2ND_TIME
    SPC_FOVFL          1024 FIFO_OVERFLOW
    SPC_SEQ_STOP      16384 STOPPED_BY_SEQUENCER
    SPC_REPTIM_OVER      32 REPEAT_TIME_ELAPSED
    SPC_REPTIM_2OVER    512 REPEAT_TIME_ELAPSED_2ND_TIME
    SPC_FEMPTY         2048 FIFO_EMPTY

    Print the correspondence from SPCM DLL names to pybhspc names.

    See Also
    --------
    measurement_state_bh_name
    """

    STOPPED_ON_OVERFLOW = 0x1
    OVERFLOW = 0x2
    STOPPED_ON_COLLECT_TIME = 0x4
    COLLECT_TIME_ELAPSED = 0x8
    STOPPED_ON_COMMAND = 0x10
    REPEAT_TIME_ELAPSED = 0x20
    ARMED = 0x80
    COLLECT_TIME_ELAPSED_2ND_TIME = 0x100
    REPEAT_TIME_ELAPSED_2ND_TIME = 0x200

    # Some of the remaining bits have more than one meaning. Make sure to list
    # the names for FIFO mode first, and newer module types first, because the
    # first appearance of the value determines the default name.

    # FIFO modes
    FIFO_OVERFLOW = 0x400
    FIFO_EMPTY = 0x800

    # FIFO Image mode
    WAITING_FOR_FRAME = 0x2000

    # SPC-700/730, 140, 830, 930, 150(N), 130EM(N), 160, 180N, 130IN
    MEASUREMENT_ACTIVE = 0x40
    SCAN_READY = 0x400
    SCAN_FLOWBACK_READY = 0x800
    WAITING_FOR_TRIGGER = 0x1000
    HARDWARE_FILL_NOT_READY = 0x8000

    # SPC-140, 150(N), 130EM(N), 160, 180N, 130IN
    STOPPED_BY_SEQUENCER = 0x4000

    # SPC-150(N), 130EM(N), 160, 180N, 130IN
    SEQUENCER_GAP_150 = 0x2000
    # SPC-600/630, 130 only
    SEQUENCER_GAP = 0x40

    # DPC-200
    TDC1_ARMED = 0x80
    TDC1_COLLECT_TIME_ELAPSED = 0x8
    TDC1_FIFO_EMPTY = 0x100
    TDC1_FIFO_OVERFLOW = 0x400
    TDC2_ARMED = 0x4000
    TDC2_COLLECT_TIME_ELAPSED = 0x20
    TDC2_FIFO_EMPTY = 0x200
    TDC2_FIFO_OVERFLOW = 0x800


_measurement_state_to_bh_name = {
    "STOPPED_ON_OVERFLOW": "OVERFL",
    "OVERFLOW": "OVERFLOW",
    "STOPPED_ON_COLLECT_TIME": "TIME_OVER",
    "COLLECT_TIME_ELAPSED": "COLTIM_OVER",
    "STOPPED_ON_COMMAND": "CMD_STOP",
    "REPEAT_TIME_ELAPSED": "REPTIM_OVER",
    "ARMED": "ARMED",
    "COLLECT_TIME_ELAPSED_2ND_TIME": "COLTIM_2OVER",
    "REPEAT_TIME_ELAPSED_2ND_TIME": "REPTIM_2OVER",
    "FIFO_OVERFLOW": "FOVFL",
    "FIFO_EMPTY": "FEMPTY",
    "WAITING_FOR_FRAME": "WAIT_FR",
    "MEASUREMENT_ACTIVE": "MEASURE",
    "SCAN_READY": "SCRDY",
    "SCAN_FLOWBACK_READY": "FBRDY",
    "WAITING_FOR_TRIGGER": "WAIT_TRG",
    "HARDWARE_FILL_NOT_READY": "HFILL_NRDY",
    "STOPPED_BY_SEQUENCER": "SEQ_STOP",
    "SEQUENCER_GAP_150": "SEQ_GAP150",
    "SEQUENCER_GAP": "SEQ_GAP",
    "TDC1_ARMED": "ARMED1",
    "TDC1_COLLECT_TIME_ELAPSED": "CTIM_OVER1",
    "TDC1_FIFO_EMPTY": "FEMPTY1",
    "TDC1_FIFO_OVERFLOW": "FOVFL1",
    "TDC2_ARMED": "ARMED2",
    "TDC2_COLLECT_TIME_ELAPSED": "CTIM_OVER2",
    "TDC2_FIFO_EMPTY": "FEMPTY2",
    "TDC2_FIFO_OVERFLOW": "FOVFL2",
}


def measurement_state_bh_name(name: str) -> str:
    """
    Map `MeasurementState` enum member names to their SPCM DLL names.

    Parameters
    ----------
    name : str
        The pybhspc `MeasurementState` enum member name.

    Returns
    -------
    str
        The corresponding SPCM DLL constant name.

    See Also
    --------
    MeasurementState
    """
    return f"SPC_{_measurement_state_to_bh_name[name]}"


class SyncState(enum.Flag):
    """
    Flag enum for sync state.

    Values of this type are returned by `get_sync_state`.

    There are two flags: `SYNC_OK` (bit 0) and `SYNC_OVERLOAD` (bit 1). When
    the `SYNC_OVERLOAD` bit is set, the `SYNC_OK` bit is invalid.
    """

    SYNC_OK = 0x1
    SYNC_OVERLOAD = 0x2


class FIFOType(enum.Enum):
    """
    Enum of FIFO data formats.

    Values of this type are returned by `get_fifo_init_vars` as an attribute of
    `FIFOInitVars`.

    Examples
    --------
    >>> for e in FIFOType:
    ...     print(e.name, e.value)
    SPC_600_48BIT 2
    SPC_600_32BIT 3
    SPC_130 4
    SPC_830 5
    SPC_140 6
    SPC_150 7
    DPC_230 8
    IMAGE 9
    TDC 11
    TDC_ABS 12
    UNKNOWN 0

    Print a table of all enum members.
    """

    SPC_600_48BIT = 2
    SPC_600_32BIT = 3
    SPC_130 = 4
    SPC_830 = 5
    SPC_140 = 6
    SPC_150 = 7
    DPC_230 = 8
    IMAGE = 9
    TDC = 11
    TDC_ABS = 12

    UNKNOWN = 0  # Attested when not in FIFO mode.

    @classmethod
    def _missing_(cls, value: int) -> FIFOType:
        return cls.UNKNOWN


class StreamType(enum.Flag):
    """
    Flag enum for properties of SPCM DLL streams.

    Values of this type are returned by `get_fifo_init_vars` as an attribute of
    `FIFOInitVars`.

    Examples
    --------
    >>> for f in StreamType:
    ...     print(f.name, f.value)
    HAS_SPC_HEADER 1
    HAS_MARKERS 512
    RAW_DATA 1024
    SPC_QC 2048
    BUFFERED 4096
    AUTOFREE_BUFFER 8192
    RING_BUFFER 16384
    DPC_TDC1_RAW_DATA 2
    DPC_TDC2_RAW_DATA 4
    DPC_TDC_TTL_RAW_DATA 8
    DPC 256

    Print a table of all flag members.

    Notes
    -----
    pybhspc does not support the SPCM DLL stream functions.
    """

    HAS_SPC_HEADER = 1 << 0
    HAS_MARKERS = 1 << 9
    RAW_DATA = 1 << 10
    SPC_QC = 1 << 11
    BUFFERED = 1 << 12
    AUTOFREE_BUFFER = 1 << 13
    RING_BUFFER = 1 << 14

    # DPC-230
    DPC_TDC1_RAW_DATA = 1 << 1
    DPC_TDC2_RAW_DATA = 1 << 2
    DPC_TDC_TTL_RAW_DATA = 1 << 3
    DPC = 1 << 8


@dataclasses.dataclass
class FIFOInitVars:
    """
    Dataclass aggregating the return values of `get_fifo_init_vars`.

    Attributes
    ----------
    fifo_type : FIFOType
        FIFO data format.
    stream_type : StreamType
        Stream properties.
    mt_clock : int
        Macrotime clock units in units of 0.1 ns (or 1 fs in the case of
        DPC-230).
    spc_header : array.array
        4-byte .spc file header. In the case of SPC-600/630 FIFO-48 format, two
        zero bytes should be appended to form the 6-byte file header.
    """

    fifo_type: FIFOType
    stream_type: StreamType
    mt_clock: int
    spc_header: array.array


def get_error_string(error_id: int | ErrorEnum) -> str:
    """
    Return the error message for the given SPCM error code.

    Parameters
    ----------
    error_id : int or ErrorEnum
        The error code

    Returns
    -------
    str
        The error message
    """
    if isinstance(error_id, ErrorEnum):
        error_id = error_id.value
        if error_id > 32767 or error_id < -32768:
            return "Unknown SPCM error"
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
    status = _spcm.SPC_get_init_status(mod_no)
    if status == ErrorEnum.MOD_NO.value:
        _raise_spcm_error(status)
    return InitStatus(status)


def get_mode() -> DLLOperationMode:
    """
    Get the operation mode of the SPCM DLL.

    Returns
    -------
    DLLOperationMode
        The mode, either hardware or simulation of a module type.

    Raises
    ------
    SPCMError
        If there was an error (e.g., if the DLL is not initialized).
    """
    ret = _spcm.SPC_get_mode()
    # Not mentioned in the docs, but the return value can be an error code.
    _raise_spcm_error(ret)
    return DLLOperationMode(ret)


def set_mode(
    mode: DLLOperationMode, force_use: bool, use: Sequence[bool]
) -> None:
    """
    Set the operation mode of the SPCM DLL and activate or deactivate each of
    the SPC modules.

    Parameters
    ----------
    mode : DLLOperationMode
        The operation mode specifying hardware or simulation module type.
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
    cdef array.array u = array.array('i', ((1 if b else 0) for b in use))
    u.extend(0 for _ in range(len(use), max_mods))
    _raise_spcm_error(
        _spcm.SPC_set_mode(mode.value, force_use, u.data.as_ints)
    )


def test_id(mod_no: int) -> ModuleType:
    """
    Return the module type (model number) of the given SPC module.

    The return value is not accurate if called before `init`.

    Parameters
    ----------
    mod_no : int
        The SPC module index.

    Returns
    -------
    ModuleType
        The module type enum.
    """
    ret = _spcm.SPC_test_id(mod_no)
    _raise_spcm_error(ret)
    return ModuleType(ret)


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
    """
    cdef ModInfo mod_info = ModInfo()
    _raise_spcm_error(_spcm.SPC_get_module_info(mod_no, &mod_info.c))
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
    """
    # SPC_get_version() is not fully documented but it is mentioned in the SPCM
    # DLL documentation as a method to check the FPGA version.
    # The version number is shown in hex in BH literature, so use unsigned
    # short.
    cdef unsigned short version = 0
    _raise_spcm_error(_spcm.SPC_get_version(mod_no, <short *>&version))
    return f"{version:X}"


def get_parameters(mod_no: int) -> Data:
    """
    Get all parameter values of an SPC module.

    Parameters
    ----------
    mod_no : int
        The SPC module index.

    Returns
    -------
    Data
        The parameter values.
    """
    cdef Data data = Data()
    _raise_spcm_error(_spcm.SPC_get_parameters(mod_no, &data.c))
    return data


def set_parameters(mod_no: int, data: Data) -> None:
    """
    Set all parameter values of an SPC module.

    Parameters
    ----------
    mod_no : int
        The SPC module index.
    data : Data
        The parameter values.
    """
    _raise_spcm_error(_spcm.SPC_set_parameters(mod_no, &data.c))


def get_parameter(mod_no: int, par_id: ParID) -> float | int:
    """
    Get one parameter's value.

    Parameters
    ----------
    mod_no : int
        The SPC module index.
    par_id : ParID
        The parameter to read.

    Returns
    -------
    float or int
        The parameter value.
    """
    cdef float value = 0.0
    _raise_spcm_error(_spcm.SPC_get_parameter(mod_no, par_id.value, &value))
    if par_id.type is int:
        return int(value)
    assert par_id.type is float
    return value


def set_parameter(mod_no: int, par_id: ParID, value: float | int) -> None:
    """
    Set one parameter's value.

    Parameters
    ----------
    mod_no : int
        The SPC module index.
    par_id : ParID
        The parameter to write.
    value : float or int
        The parameter value.
    """
    if par_id.type is int and isinstance(value, float):
        raise TypeError(f"{par_id.name} takes an integer value; float found")
    cdef float v = value
    _raise_spcm_error(_spcm.SPC_set_parameter(mod_no, par_id.value, value))


def get_eeprom_data(mod_no: int) -> EEPData:
    """
    Get EEPROM data of an SPC module.

    Parameters
    ----------
    mod_no : int
        The SPC module index.

    Returns
    -------
    EEPData
        EEPROM data of the module.
    """
    cdef EEPData eep_data = EEPData()
    _raise_spcm_error(_spcm.SPC_get_eeprom_data(mod_no, &eep_data.c))
    return eep_data


def get_adjust_parameters(mod_no: int) -> AdjustPara:
    """
    Get adjustment parameters of an SPC module.

    Parameters
    ----------
    mod_no : int
        The SPC module index.

    Returns
    -------
    AdjustPara
        Adjustment parameters of the module.
    """
    cdef AdjustPara adjpara = AdjustPara()
    _raise_spcm_error(_spcm.SPC_get_adjust_parameters(mod_no, &adjpara.c))
    return adjpara


def read_parameters_from_inifile(inifile: bytes | str) -> Data:
    """
    Read an .ini file in the spcm.ini format.

    The .ini file must contain a first-line comment starting with (whitespace
    followed by) `SPCM`, an ``[spc_base]`` section, and an ``[spc_module]``
    section. The sections may be empty but the section headers need to be
    terminated with a newline.

    Parameters
    ----------
    inifile : bytes or str
        Filename of the .ini file.

    Returns
    -------
    Data
        The parameters read from the .ini file.
    """
    if isinstance(inifile, str):
        inifile = inifile.encode()
    cdef Data data = Data()
    _raise_spcm_error(_spcm.SPC_read_parameters_from_inifile(&data.c, inifile))
    return data


def save_parameters_to_inifile(
    data: Data,
    dest_inifile: bytes | str,
    *,
    source_inifile: bytes | str | None = None,
    with_comments: bool = False,
) -> None:
    """
    Save parameters to an .ini file in the spcm.ini format.

    A source .ini file is required for this function to work, optionally given
    by `source_inifile`. If not given, the filename previously passed to `init`
    is used. Either way, this file must exist and must contain a first-line
    comment starting with (whitespace followed by) `SPCM`, an ``[spc_base]``
    section, and an ``[spc_module]`` section. The sections may be empty but the
    section headers need to be terminated with a newline.

    When `with_comments` is True, it appears that there need to be at least 2
    fields set in the ``[spc_module]`` section of the ``source_inifile``. The
    precise requirements have not been determined.

    Parameters
    ----------
    data : Data
        The parameters to save.
    dest_inifile : bytes or str
        Filename of the .ini file to write.
    source_inifile : bytes or str or None
        Filename of an .ini file from which to copy initial comment lines and
        the ``[spc_base]`` section. If None, the .ini file passed to ``init()``
        is used.
    with_comments : bool
        If True, also copy parameter comments from `source_inifile`.
    """
    if isinstance(dest_inifile, str):
        dest_inifile = dest_inifile.encode()
    if isinstance(source_inifile, str):
        source_inifile = source_inifile.encode()
    if source_inifile is None:
        _raise_spcm_error(
            _spcm.SPC_save_parameters_to_inifile(
                &data.c, dest_inifile, NULL, (1 if with_comments else 0)
            )
        )
    else:
        _raise_spcm_error(
            _spcm.SPC_save_parameters_to_inifile(
                &data.c,
                dest_inifile,
                source_inifile,
                (1 if with_comments else 0),
            )
        )


def test_state(mod_no: int) -> MeasurementState:
    """
    Get various status flags for the last-started measurement.

    This function should be called periodically during a measurement in order
    to detect when the measurement is stopped (among other things).

    Parameters
    ----------
    mod_no : int
        The SPC module index.

    Returns
    -------
    MeasurementState
        Flags indicating timer and FIFO states, reason for measurement stop,
        etc.
    """
    cdef short state = 0
    _raise_spcm_error(_spcm.SPC_test_state(mod_no, &state))
    return MeasurementState(state)


def get_sync_state(mod_no: int) -> SyncState:
    """
    Get the state of the SYNC input.

    Parameters
    ----------
    mod_no : int
        The SPC module index.

    Returns
    -------
    SyncState
        Whether the SYNC signal is triggering and whether it is overloaded.
    """
    cdef short sync_state = 0
    _raise_spcm_error(_spcm.SPC_get_sync_state(mod_no, &sync_state))
    return SyncState(sync_state)


def get_time_from_start(mod_no: int) -> float:
    """
    Get the time since measurement start.

    `test_state` must be called periodically for this function to work
    correctly during measurements that exceed 80 seconds.

    Parameters
    ----------
    mod_no : int
        The SPC module index.

    Returns
    -------
    float
        Elapsed time since measurement start, in seconds.
    """
    cdef float time = 0.0
    _raise_spcm_error(_spcm.SPC_get_time_from_start(mod_no, &time))
    return time


def get_break_time(mod_no: int) -> float:
    """
    Get the time from measurement start to stop or pause.

    The return value may not be valid in FIFO mode (to be investigated).

    Parameters
    ----------
    mod_no : int
        The SPC module index.

    Returns
    -------
    float
        Duration of measurement in seconds.
    """
    cdef float time = 0.0
    _raise_spcm_error(_spcm.SPC_get_break_time(mod_no, &time))
    return time


def get_actual_coltime(mod_no: int) -> float:
    """
    Get the remaining time to the end of the measurement, taking dead time
    compensation into account.

    Under some conditions (e.g., in FIFO mode with STOP_ON_TIME disabled), the
    return value counts up similarly to `get_time_from_start`.

    `test_state` must be called periodically for this function to work
    correctly during measurements that exceed 80 seconds.

    Parameters
    ----------
    mod_no : int
        The SPC module index.

    Returns
    -------
    float
        Remaining or elapsed collection time, in seconds.
    """
    cdef float time = 0.0
    _raise_spcm_error(_spcm.SPC_get_actual_coltime(mod_no, &time))
    return time


def clear_rates(mod_no: int) -> None:
    """
    Initialize and clear the rate counters and start a count cycle.

    Parameters
    ----------
    mod_no : int
        The SPC module index.
    """
    _raise_spcm_error(_spcm.SPC_clear_rates(mod_no))


def read_rates(mod_no: int) -> RateValues | None:
    """
    Read the rate counters and start a new count cycle.

    Parameters
    ----------
    mod_no : int
        The SPC module index.

    Returns
    -------
    RateValues or None
        The rate counts, or None if a count cycle has not yet completed.
    """
    cdef RateValues rates = RateValues()
    ret = _spcm.SPC_read_rates(mod_no, &rates.c)
    if ret == -ErrorEnum.RATES_NOT_RDY.value:
        return None
    _raise_spcm_error(ret)
    return rates


def get_fifo_usage(mod_no: int) -> float:
    """
    Get the used fraction of the FIFO.

    Parameters
    ----------
    mod_no : int
        The SPC module index.

    Returns
    -------
    float
        The fraction of the FIFO occupied (0.0 to 1.0).
    """
    cdef float usage_degree = 0.0
    _raise_spcm_error(_spcm.SPC_get_fifo_usage(mod_no, &usage_degree))
    return usage_degree


def start_measurement(mod_no: int) -> None:
    """
    Start a measurement.

    Parameters
    ----------
    mod_no : int
        The SPC module index.
    """
    _raise_spcm_error(_spcm.SPC_start_measurement(mod_no))


def stop_measurement(mod_no: int) -> None:
    """
    Stop any ongoing measurement.

    Parameters
    ----------
    mod_no : int
        The SPC module index.
    """
    _raise_spcm_error(_spcm.SPC_stop_measurement(mod_no))


def read_fifo(mod_no: int, unsigned short[::1] data not None) -> int:
    """
    Read data from a FIFO mode measurement.

    Parameters
    ----------
    mod_no : int
        The SPC module index.
    data : array_like
        The destination buffer for the data read. The object must implement the
        buffer protocol, be typed unsigned short (uint16), be 1-dimentional,
        and be C-contiguous. For example, ``np.empty(65536, dtype=np.uint16)``.

    Returns
    -------
    int
        The number of 16-bit words read. Thus, if the return value is ``r``,
        ``data[:r]`` contains valid data.
    """
    if data.shape[0] > 2**32 - 1:
        raise ValueError("Cannot read size that doesn't fit in 32 bits")
    cdef unsigned long count = <unsigned long>(data.shape[0])
    if count == 0:  # Cannot write &data[0].
        _raise_spcm_error(_spcm.SPC_read_fifo(mod_no, &count, NULL))
    else:
        _raise_spcm_error(_spcm.SPC_read_fifo(mod_no, &count, &data[0]))
    return count


def read_fifo_to_array(mod_no: int, max_words: int) -> array.array:
    """
    Convenience wrapper around `read_fifo` that allocates an array for the
    output.

    Parameters
    ----------
    mod_no : int
        The SPC module index.
    max_words:
        Maximum number of 16-bit words to read.

    Returns
    -------
    array.array of unsigned short
        The FIFO data read. The length of the array is between 0 and
        `max_words`.
    """
    cdef array.array data = array.array('H')
    array.resize(data, max_words)
    return data[:read_fifo(mod_no, data)]


def get_fifo_init_vars(mod_no: int) -> FIFOInitVars:
    """
    Get format information on the currently set FIFO mode.

    The return value is only meaningful if the module is set to a FIFO mode.

    For SPC-600/630, the number of routing bits in the SPCHeader may always be
    zero (in both FIFO formats).

    Parameters
    ----------
    mod_no : int
        The SPC module index.

    Returns
    -------
    FIFOInitVars
        The FIFO format information.
    """
    cdef short fifo_type = 0
    cdef short stream_type = 0
    cdef int mt_clock = 0
    cdef array.array spc_header = array.array('B', (0 for _ in range(4)))
    _raise_spcm_error(
        _spcm.SPC_get_fifo_init_vars(
            mod_no, &fifo_type, &stream_type, &mt_clock,
            spc_header.data.as_uints
        )
    )
    return FIFOInitVars(
        FIFOType(fifo_type), StreamType(stream_type), mt_clock, spc_header
    )
