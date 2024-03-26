# This file is part of pybhspc
# Copyright 2024 Board of Regents of the University of Wisconsin System
# SPDX-License-Identifier: MIT


import textwrap
from collections.abc import Sequence

from . import spcm  # type: ignore[attr-defined]


def _dump_eeprom_data(mod_no: int, print) -> None:
    try:
        eep_data = spcm.get_eeprom_data(mod_no)
    except spcm.SPCMError as e:
        print(f"  get_eeprom_data() failed: {e}")
    else:
        print(f"  EEPData.module_type: {eep_data.module_type}")
        print(f"  EEPData.serial_no:   {eep_data.serial_no}")
        print(f"  EEPData.date:        {eep_data.date}")


def _dump_fpga_version(mod_no: int, print) -> None:
    try:
        version = spcm.get_version(mod_no)
    except spcm.SPCMError as e:
        print(f"  get_version() failed: {e}")
    else:
        print(f"  FPGA Version:        {version}")


def _dump_measurement_state(mod_no: int, print) -> None:
    try:
        meas_state = spcm.test_state(mod_no)
    except spcm.SPCMError as e:
        print(f"  test_state() failed: {e}")
    else:
        print(f"  State:               {meas_state!r}")


def _dump_sync_state(mod_no: int, print) -> None:
    try:
        sync_state = spcm.get_sync_state(mod_no)
    except spcm.SPCMError as e:
        print(f"  get_sync_state() failed: {e}")
    else:
        print(f"  Sync state:          {sync_state!r}")


def _dump_parameters(mod_no: int, print) -> None:
    try:
        data = spcm.get_parameters(mod_no)
    except spcm.SPCMError as e:
        print(f"  get_parameters() failed: {e}")
    else:
        params = " ".join(f"{k}={v!r}" for k, v in data.items())
        print("  Parameters:")
        for line in textwrap.wrap(
            params,
            width=79,
            initial_indent="    ",
            subsequent_indent="    ",
            break_long_words=False,
            break_on_hyphens=False,
        ):
            print(line)


def dump_module_state(mod_no: int, *, file=None) -> None:
    """
    Print the status of one SPC module.

    Parameters
    ----------
    mod_no : int
        The SPC module index.
    file : file or None
        The stream to print to.
    """

    def _print(*args, **kwargs):
        kwargs["file"] = file
        print(*args, **kwargs)

    # Usually if the module is not initialized, test_id() will fail, in which
    # case we give up. But we guard against each function failing, just in
    # case, so that we have a robust dump.

    try:
        module_type = spcm.test_id(mod_no)
    except spcm.SPCMError as e:
        if e.enum == spcm.ErrorEnum.NOT_ACTIVE:
            raise
        _print(f"Module {mod_no}: test_id() failed: {e}")
        return
    _print(f"Module {mod_no}: {module_type!r}")

    try:
        init_status = spcm.get_init_status(mod_no)
    except spcm.SPCMError as e:
        init_status = f"get_init_status() failed: {e}"
    _print(f"  {init_status!r}")

    try:
        info = spcm.get_module_info(mod_no)
    except spcm.SPCMError as e:
        _print(f"  get_module_info() failed: {e}")
    else:
        if info.module_type != module_type:
            _print(f"  ModInfo.module_type: {info.module_type!r}")
        _print(f"  PCI bus/slot:        {info.bus_number}, {info.slot_number}")
        _print(f"  ModInfo.in_use:      {info.in_use!r}")
        if info.init != init_status:
            _print(f"  ModInfo.init_status: {info.init!r}")

    _dump_eeprom_data(mod_no, _print)
    _dump_fpga_version(mod_no, print)
    _dump_measurement_state(mod_no, print)
    _dump_sync_state(mod_no, print)
    _dump_parameters(mod_no, _print)


def dump_state(
    mod_nos: int | Sequence[int] | None = (0,), *, file=None
) -> None:
    """
    Print (to standard output) the status SPC modules.

    This is a utility intended mostly for troubleshooting.

    Parameters
    ----------
    mod_nos : int or Sequence[int] or None
        The SPC module index or indices for which to dump state. If None, use
        all modules.
    file : file or None
        The stream to print to.
    """
    dll_mode = spcm.get_mode()
    print(repr(dll_mode), file=file)

    if mod_nos is None:
        mod_nos = range(32)
    elif isinstance(mod_nos, int):
        mod_nos = (mod_nos,)

    for mod_no in mod_nos:
        print(file=file)
        try:
            dump_module_state(mod_no, file=file)
        except spcm.SPCMError:  # Not active
            print(f"Module {mod_no} is not active", file=file)
