<!--
This file is part of pybhspc
Copyright 2024 Board of Regents of the University of Wisconsin System
SPDX-License-Identifier: MIT
-->

# pybhspc: Control Becker & Hickl SPC modules from Python

```sh
pip install pybhspc
```

```py
import bh_spc
from bh_spc import spcm
```

[Full Documentation](https://marktsuchida.github.io/pybhspc/)

<!-- begin-intro-docs -->

## Overview

The pybhspc package provides Python bindings to the Becker & Hickl SPCM DLL,
which is the control and acquisition interface for SPC modules. (SPC moduels
are PCI/PCIe boards that perform TCSPC (time-correlated single photon counting)
or time-tagging.)

Note: The author of this package is not affiliated with Becker & Hickl GmbH.

The main package `bh_spc` provides a few utility functions. The module
`bh_spc.spcm` provides Python bindings to the SPCM functions and data types.

To use the relatively direct bindings in `bh_spc.spcm`, you will need to
understand the underlying SPCM DLL interface, provided and documented by BH.
(I plan to add a higher-level interface that simplifies device enumeration and
FIFO acquisition, but this is not yet available.)

Access to all of the functions that are required for FIFO (time tag stream)
mode acquisition on SPC boards (including with multiple boards) is provided by
the `bh_spc.spcm` module. Not supported are functions that are specific to
conventional (non-FIFO mode) acquisition, the DPC-230, and stream buffering
(data buffering can readily be done using other Python facilities).

Note that interpreting the time tag stream data (a seqeunce of binary records)
is outside the scope of this library. It's always good to keep data acquisition
and data processing/analysis code separate (even if they run concurrently in a
particular application).

## Status and Versioning

This package should be considered experimental, even though the `spcm` module
is reasonably complete for FIFO mode acquisition. Until version 1.0.0 is
released, all APIs are subject to backward-incompatible changes. However,
backward-incompatible changes will be documented following the first release
(version 0.1.0).

## Hardware Requirements

An effort has been made to avoid making unnecessary assumptions about the SPC
module type (i.e., device model). pybhspc also allows testing with the SPCM DLL
set to simulation modes.

It should be possible to operate most of the SPC boards supported by the SPCM
DLL: SPC-600, 630, 130, 830, 140, 930, 150, 130EM, 150N (NX, NXX), 130EMN, 160
(X, PCIE), 180N (NX, NXX), and 130IN (INX, INXX). Recent versions of SPCM do
not support some of the older models except in simulation; check the BH
documentation.

Caveat: Most of these have not been tested, especially with hardware.

SPC-700 and 730 are not listed here because they do not have a FIFO mode.

DPC-230 is not currently supported by pybhspc (it requires some extra functions
and data types).

SPC-QC-104 and 004 _may_ work (no attempt has been made to test these yet, even
in simulation).

SPC-QC-008 uses a completely different programming interface and is out of
scope for the pybhspc package (but BH
[offers](https://www.becker-hickl.com/products/bhpy/) a Python interface called
[bhpy](https://pypi.org/project/bhpy/) for SPC-QC-104/004/008).

## Software Requirements

Windows 10+ (64-bit Intel).

Python 3.10+ (64-bit).

The Becker & Hickl SPCM DLL (part of their [TCSPC
Package](https://www.becker-hickl.com/products/tcspc-package/) installer) must
be installed on the system. The most recent version is usually recommended;
absolute minimum is version 4.0 (Apr 2014; but versions below 5.1 have not been
tested). Note that these are version numbers of the SPCM DLL, not of the TCSPC
Package or the SPCM application.

The SPCM DLL is automatically found at its installed location; there is no need
to copy it or set any environment variables.

## License

The pybhspc package is distributed under the MIT license.

<!-- end-intro-docs -->

## Getting Started

Check out the
[example](https://marktsuchida.github.io/pybhspc/getting_started/) in the
documentation.
