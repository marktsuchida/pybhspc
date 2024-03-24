# This file is part of pybhspc
# Copyright 2024 Board of Regents of the University of Wisconsin System
# SPDX-License-Identifier: MIT

import pytest
from bh_spc import ini_file, minimal_spcm_ini, spcm


@pytest.fixture
def init_spc150():
    with ini_file(
        minimal_spcm_ini(spcm.DLLOperationMode.SIMULATE_SPC_150)
    ) as ininame:
        spcm.init(ininame)
    yield
    spcm.close()
