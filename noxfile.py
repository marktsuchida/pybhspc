# This file is part of pybhspc
# Copyright 2024 Board of Regents of the University of Wisconsin System
# SPDX-License-Identifier: MIT

"""noxfile for pybhspc."""

import nox

nox.options.sessions = ["test"]


@nox.session(python=["3.10", "3.11", "3.12"])
def test(session):
    """Run the tests."""
    session.install(".[testing]")
    session.run("pytest")


@nox.session
def docs(session):
    """Build the documentation."""
    session.install(".[dev]")
    session.run("python", "setup.py", "build_ext", "--inplace")
    session.run("mkdocs", "build")
