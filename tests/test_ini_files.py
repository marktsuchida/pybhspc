# This file is part of pybhspc
# Copyright 2024-2025 Board of Regents of the University of Wisconsin System
# SPDX-License-Identifier: MIT

import os.path

from bh_spc import ini_file, minimal_spcm_ini


def test_minimal_ini():
    text = minimal_spcm_ini(180)
    assert text.startswith("; SPCM")
    assert "simulation = 180" in text


def test_ini_file():
    with ini_file("blah") as ininame:
        assert os.path.splitext(ininame)[1] == ".ini"
        with open(ininame) as f:
            assert f.read() == "blah"
