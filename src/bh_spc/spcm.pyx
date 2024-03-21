# This file is part of pybhspc
# Copyright 2024 Board of Regents of the University of Wisconsin System
# SPDX-License-Identifier: MIT

# cython: language_level=3

import array
from enum import Enum
from collections.abc import Sequence

from cpython cimport array
from libc.string cimport memcmp, memcpy, memset, strlen

from . cimport _spcm


assert sizeof(_spcm.SPCdata) == 256  # TODO Move to wrapper def


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
    cdef _spcm.SPCModInfo c

    def __cinit__(self):
        memset(&self.c, 0, sizeof(_spcm.SPCModInfo))

    def __repr__(self) -> str:
        return "<ModInfo({})>".format(
            ", ".join(f"{f}={repr(getattr(self, f))}" for f in self._fields)
        )

    def as_dict(self) -> dict:
        """
        Return a dictionary containing the fields and values.

        Returns
        -------
        dict
            Every field and its value.
        """
        return {f: getattr(self, f) for f in self._fields}

    _fields = [
        "module_type",
        "bus_number",
        "slot_number",
        "in_use",
        "init",
    ]

    @property
    def module_type(self) -> int:
        return self.c.module_type

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
        return _make_init_status(self.c.init)

    # Leave out base_adr. It is not valid on 64-bit.


cdef class Data:
    cdef _spcm.SPCdata c

    def __cinit__(self):
        memset(&self.c, 0, sizeof(_spcm.SPCdata))

    def __copy__(self) -> Data:
        cdef Data cpy = Data()
        memcpy(&cpy.c, &self.c, sizeof(_spcm.SPCdata))
        return cpy

    def __deepcopy__(self, memo) -> Data:
        # There are no objects stored by reference.
        return self.__copy__()

    def __eq__(self, other) -> bool:
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

    def as_dict(self) -> dict:
        """
        Return a dictionary containing the fields and values.

        Returns
        -------
        dict
            Every field and its value.
        """
        return {f: getattr(self, f) for f in self._fields}

    def diff_as_dict(self, other: Data) -> dict:
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
            instance.
        """
        ret = {}
        for f in self._fields:
            v = getattr(self, f)
            if v != getattr(other, f):
                ret[f] = v
        return ret

    # We omit the non-parameter fields of SPCdata: base_adr, init, pci_card_no,
    # and test_eep. These fields are redundant and not useful here. None of
    # them are writable. 'base_adr' is no longer used (in 64-bit, at least). If
    # 'init' were not 0 (OK), SPC_get_parameters() would have failed anyway. If
    # 'test_eep' were not 1, again, initialization would have failed and
    # SPC_get_parameters() would therefore have failed. Finally, 'pci_card_no'
    # is redundant with ModInfo.

    # The rest of the fields are regular parameters and are in the same order
    # as the C struct. These wrappers should be kept regular: all parameters
    # of the same type should be wrapped in exactly the same way. Use editor
    # macros to make uniform changes.

    _fields = (
        "cfd_limit_low",
        "cfd_limit_high",
        "cfd_zc_level",
        "cfd_holdoff",
        "sync_zc_level",
        "sync_holdoff",
        "sync_threshold",
        "tac_range",
        "sync_freq_div",
        "tac_gain",
        "tac_offset",
        "tac_limit_low",
        "tac_limit_high",
        "adc_resolution",
        "ext_latch_delay",
        "collect_time",
        "display_time",
        "repeat_time",
        "stop_on_time",
        "stop_on_ovfl",
        "dither_range",
        "count_incr",
        "mem_bank",
        "dead_time_comp",
        "scan_control",
        "routing_mode",
        "tac_enable_hold",
        "mode",
        "scan_size_x",
        "scan_size_y",
        "scan_rout_x",
        "scan_rout_y",
        "scan_flyback",
        "scan_borders",
        "scan_polarity",
        "pixel_clock",
        "line_compression",
        "trigger",
        "pixel_time",
        "ext_pixclk_div",
        "rate_count_time",
        "macro_time_clk",
        "add_select",
        "adc_zoom",
        "img_size_x",
        "img_size_y",
        "img_rout_x",
        "img_rout_y",
        "xy_gain",
        "master_clock",
        "adc_sample_delay",
        "detector_type",
        "chan_enable",
        "chan_slope",
        "chan_spec_no",
        "tdc_control",
        "tdc_offset",
    )

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
    def sync_freq_div(self) -> int:
        return self.c.sync_freq_div

    @sync_freq_div.setter
    def sync_freq_div(self, v: int) -> None:
        self.c.sync_freq_div = v

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
    def scan_polarity(self) -> int:
        return self.c.scan_polarity

    @scan_polarity.setter
    def scan_polarity(self, v: int) -> None:
        self.c.scan_polarity = v

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
    def pixel_time(self) -> float:
        return self.c.pixel_time

    @pixel_time.setter
    def pixel_time(self, v: float) -> None:
        self.c.pixel_time = <float>v

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
    def xy_gain(self) -> int:
        return self.c.xy_gain

    @xy_gain.setter
    def xy_gain(self, v: int) -> None:
        self.c.xy_gain = v

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

    @property
    def tdc_control(self) -> int:
        return self.c.tdc_control

    @tdc_control.setter
    def tdc_control(self, v: int) -> None: self.c.tdc_control = v

    @property
    def tdc_offset(self) -> tuple[int, int, int, int]:
        return tuple(self.c.tdc_offset)

    @tdc_offset.setter
    def tdc_offset(self, v: tuple[int, int, int, int]) -> None:
        self.c.tdc_offset = v


cdef class AdjustPara:
    cdef _spcm.SPC_Adjust_Para c

    def __cinit__(self):
        memset(&self.c, 0, sizeof(_spcm.SPC_Adjust_Para))

    def __repr__(self) -> str:
        return "<AdjustPara({})>".format(
            ", ".join(f"{f}={repr(getattr(self, f))}" for f in self._fields)
        )

    def as_dict(self) -> dict:
        """
        Return a dictionary containing the fields and values.

        Returns
        -------
        dict
            Every field and its value.
        """
        return {f: getattr(self, f) for f in self._fields}

    _fields = [
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
    ]

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
    cdef _spcm.SPC_EEP_Data c

    def __cinit__(self):
        memset(&self.c, 0, sizeof(_spcm.SPC_EEP_Data))

    def __repr__(self) -> str:
        return "<EEPData({})>".format(
            ", ".join(f"{f}={repr(getattr(self, f))}" for f in self._fields)
        )

    def as_dict(self) -> dict:
        """
        Return a dictionary containing the fields and values.

        Returns
        -------
        dict
            Every field and its value.
        """
        return {f: getattr(self, f) for f in self._fields}

    _fields = [
        "module_type",
        "serial_no",
        "date",
        "adj_para",
    ]

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
    cdef _spcm.rate_values c

    def __cinit__(self):
        memset(&self.c, 0, sizeof(_spcm.rate_values))

    def __repr__(self) -> str:
        return "<RateValues({})>".format(
            ", ".join(f"{f}={repr(getattr(self, f))}" for f in self._fields)
        )

    def as_dict(self) -> dict:
        """
        Return a dictionary containing the fields and values.

        Returns
        -------
        dict
            Every field and its value.
        """
        return {f: getattr(self, f) for f in self._fields}

    _fields = [
        "sync_rate",
        "cfd_rate",
        "tac_rate",
        "adc_rate",
    ]

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


def test_id(mod_no: int) -> int:
    """
    """
    ret = _spcm.SPC_test_id(mod_no)
    _raise_spcm_error(ret)
    return ret


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


def get_parameters(mod_no: int) -> Data:
    cdef Data data = Data()
    _raise_spcm_error(_spcm.SPC_get_parameters(mod_no, &data.c))
    return data


def set_parameters(mod_no: int, Data data) -> None:
    _raise_spcm_error(_spcm.SPC_set_parameters(mod_no, &data.c))


def get_parameter(mod_no: int, par_id: int) -> float | int:
    cdef float value = 0.0
    _raise_spcm_error(_spcm.SPC_get_parameter(mod_no, par_id, &value))
    if False:  # TODO If parameter is integer type
        return int(value)
    return value


def set_parameter(mod_no: int, par_id: int, value: float | int) -> None:
    cdef float v = value
    _raise_spcm_error(_spcm.SPC_set_parameter(mod_no, par_id, value))


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

    Riases
    ------
    SPCMError
        If there was an error.
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

    Riases
    ------
    SPCMError
        If there was an error.
    """
    cdef AdjustPara adjpara = AdjustPara()
    _raise_spcm_error(_spcm.SPC_get_adjust_parameters(mod_no, &adjpara.c))
    return adjpara
