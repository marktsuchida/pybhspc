# This file is part of pybhspc
# Copyright 2024 Board of Regents of the University of Wisconsin System
# SPDX-License-Identifier: MIT

import re

import pytest
from bh_spc import dump_state, ini_file, minimal_spcm_ini, spcm


def test_get_error_string():
    assert spcm.get_error_string(0) == "No error"
    assert "file" in spcm.get_error_string(-1).lower()
    with pytest.raises(OverflowError):
        spcm.get_error_string(32768)


def test_init_close():
    with ini_file(minimal_spcm_ini(150)) as ininame:
        spcm.init(ininame)  # Simulated should always succeed.
    spcm.close()


def test_failed_init():
    with ini_file("invalid") as ininame, pytest.raises(
        spcm.SPCMError, match=re.escape("(-2)")
    ):
        spcm.init(ininame)


@pytest.fixture
def ini150():
    with ini_file(minimal_spcm_ini(150)) as ininame:
        spcm.init(ininame)
    yield
    spcm.close()


def test_get_init_status(ini150):
    assert spcm.get_init_status(0) == spcm.InitStatus.OK
    with pytest.raises(spcm.SPCMError, match=re.escape("(-32)")):
        spcm.get_init_status(1000)


def test_get_mode(ini150):
    assert spcm.get_mode() == 150
    # Would be good to also test that SPCMError is raised when not initialized,
    # but the uninitialized state cannot be reproduced with
    # SPC_close() (so we would need to test in a dedicated fresh process).


def test_set_mode(ini150):
    spcm.set_mode(180, False, (True,))
    assert spcm.get_mode() == 180
    assert spcm.get_init_status(0) == spcm.InitStatus.OK
    assert spcm.get_init_status(1) == spcm.InitStatus.NOT_DONE
    assert spcm.get_init_status(7) == spcm.InitStatus.NOT_DONE


def test_get_module_info(ini150):
    info = spcm.get_module_info(0)
    assert info.module_type == 150
    assert info.in_use == spcm.InUseStatus.IN_USE_HERE
    assert info.init == spcm.InitStatus.OK


def test_disabled_module(ini150):
    spcm.set_mode(150, False, (True,))
    info = spcm.get_module_info(1)
    assert info.module_type == 150
    assert info.in_use == spcm.InUseStatus.NOT_IN_USE
    assert info.init == spcm.InitStatus.NOT_DONE


def test_disabling_all_modules_raises(ini150):
    with pytest.raises(spcm.SPCMError, match=re.escape("(-31)")):
        spcm.set_mode(150, False, ())


def test_get_version(ini150):
    # We assume simulated modules return 0 as version. Don't know if this is
    # always the case.
    assert spcm.get_version(0) == "0"


def test_dump_state(ini150):
    dump_state()
