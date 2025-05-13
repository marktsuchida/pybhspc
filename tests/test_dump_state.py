# This file is part of pybhspc
# Copyright 2024-2025 Board of Regents of the University of Wisconsin System
# SPDX-License-Identifier: MIT

import io

import pytest

from bh_spc import dump_module_state, dump_state, spcm


def test_dump_module_state(init_spc150):
    dump_module_state(0)

    spcm.set_mode(spcm.DLLOperationMode.SIMULATE_SPC_150, False, (True,))
    with pytest.raises(spcm.SPCMError):
        dump_module_state(1)

    sio = io.StringIO()
    dump_module_state(0, file=sio)
    assert len(sio.getvalue()) > 0


def test_dump_state(init_spc150):
    dump_state()
    dump_state(2)
    dump_state((2, 3))
    dump_state(None)

    spcm.set_mode(spcm.DLLOperationMode.SIMULATE_SPC_150, False, (True,))
    dump_state(1)  # Does not raise!

    sio = io.StringIO()
    dump_state(file=sio)
    assert len(sio.getvalue()) > 0
