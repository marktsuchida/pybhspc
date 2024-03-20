<!--
This file is part of pybhspc
Copyright 2024 Board of Regents of the University of Wisconsin System
SPDX-License-Identifier: MIT
-->

# pybhspc: Control Becker-Hickl SPC devices in Python

(Introduction coming.)

## Requirements

Windows 10+ (64-bit Intel) only.

The Becker-Hickl SPCM DLL (part of their "TCSPC Package" installer) must be
installed on the system. The most recent version is usually recommended;
absolute minimum is version 4.0 (Apr 2014; but versions below 5.2 have not been
tested). Note that these are version numbers of the SPCM DLL, not of the TCSPC
Package.

_Building_ pybhspc requires SPCM DLL 5.1.0 (Dec 2022) or later to be installed.

## Development

### Building and testing

In a virtual environment, for fast iteration:

```sh
pip install .[dev]  # Run this once
pip install --no-build-isolation -e .  # Also run once (editable install)
python setup.py build_ext --inplace  # Run after changing .pxd/.pyx files
pytest
```

(`--no-build-isolation` allows for faster builds but requires build
requirements to be pre-installed.)

To run tests in an isolated environment (as in CI):

```sh
pip install nox  # Also included in 'pip install .[dev]'
nox
```
