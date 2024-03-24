# This file is part of pybhspc
# Copyright 2024 Board of Regents of the University of Wisconsin System
# SPDX-License-Identifier: MIT


import textwrap
from collections.abc import Sequence

from . import spcm  # type: ignore


def dump_module_state(mod_no: int, *, file=None) -> None:
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
    _print(f"Module {mod_no}: {repr(module_type)}")

    try:
        init_status = spcm.get_init_status(mod_no)
    except spcm.SPCMError as e:
        init_status = f"get_init_status() failed: {e}"
    _print(f"  {repr(init_status)}")

    try:
        info = spcm.get_module_info(mod_no)
    except spcm.SPCMError as e:
        _print(f"  get_module_info() failed: {e}")
    else:
        if info.module_type != module_type:
            _print(f"  ModInfo.module_type: {repr(info.module_type)}")
        _print(f"  PCI bus/slot:        {info.bus_number}, {info.slot_number}")
        _print(f"  ModInfo.in_use:      {repr(info.in_use)}")
        if info.init != init_status:
            _print(f"  ModInfo.init_status: {repr(info.init)}")

    try:
        eep_data = spcm.get_eeprom_data(mod_no)
    except spcm.SPCMError as e:
        _print(f"  get_eeprom_data() failed: {e}")
    else:
        _print(f"  EEPData.module_type: {eep_data.module_type}")
        _print(f"  EEPData.serial_no:   {eep_data.serial_no}")
        _print(f"  EEPData.date:        {eep_data.date}")

    try:
        version = spcm.get_version(mod_no)
    except spcm.SPCMError as e:
        _print(f"  get_version() failed: {e}")
    else:
        _print(f"  FPGA Version:        {version}")

    try:
        meas_state = spcm.test_state(mod_no)
    except spcm.SPCMError as e:
        _print(f"  test_state() failed: {e}")
    else:
        _print(f"  State:               {repr(meas_state)}")

    try:
        sync_state = spcm.get_sync_state(mod_no)
    except spcm.SPCMError as e:
        _print(f"  get_sync_state() failed: {e}")
    else:
        _print(f"  Sync state:          {repr(sync_state)}")

    try:
        data = spcm.get_parameters(mod_no)
    except spcm.SPCMError as e:
        _print(f"  get_parameters() failed: {e}")
    else:
        params = " ".join(f"{k}={repr(v)}" for k, v in data.items())
        _print("  Parameters:")
        for line in textwrap.wrap(
            params,
            width=79,
            initial_indent="    ",
            subsequent_indent="    ",
            break_long_words=False,
            break_on_hyphens=False,
        ):
            _print(line)


def dump_state(
    mod_nos: int | Sequence[int] | None = (0,), *, file=None
) -> None:
    """
    Print (to standard output) the status of all 8 SPC modules.

    This is a utility intended mostly for troubleshooting.
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
