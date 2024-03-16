# This file is part of pybhspc
# Copyright 2024 Board of Regents of the University of Wisconsin System
# SPDX-License-Identifier: MIT

import nox

nox.options.sessions = ["test"]


@nox.session
def test(session):
    session.install(".[testing]")
    session.run("pytest")
