# This file is part of pybhspc
# Copyright 2024 Board of Regents of the University of Wisconsin System
# SPDX-License-Identifier: MIT

"""noxfile for pybhspc."""

import nox

nox.options.sessions = ["test"]

py_versions = ["3.10", "3.11", "3.12"]


@nox.session(python=py_versions)
def test(session):
    """Run the tests."""
    session.install(".[testing]")
    session.run("pytest")


@nox.session(python=py_versions)
def build(session):
    """Build wheels."""
    session.install("build")
    session.run("python", "-m", "build")


@nox.session
def docs(session):
    """Build the documentation."""
    session.install(".[dev]")
    session.run("python", "setup.py", "build_ext", "--inplace")
    session.run("mkdocs", "build")
