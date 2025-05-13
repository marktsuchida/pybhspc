# This file is part of pybhspc
# Copyright 2024-2025 Board of Regents of the University of Wisconsin System
# SPDX-License-Identifier: MIT

import re

import bh_spc


def test_version():
    assert re.match(r"^[0-9]+\.[0-9]+\.", bh_spc.__version__)
