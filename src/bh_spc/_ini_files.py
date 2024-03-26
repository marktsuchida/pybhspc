# This file is part of pybhspc
# Copyright 2024 Board of Regents of the University of Wisconsin System
# SPDX-License-Identifier: MIT

import contextlib
import os
import tempfile
from typing import Iterator

from . import spcm  # type: ignore[attr-defined]


def minimal_spcm_ini(mode: int | spcm.DLLOperationMode = 0) -> str:
    """
    Return the text for a minimal .ini file for use with `spcm.init`.

    The generated .ini text does not set any of the device parameters, and
    attempts to initialize all available SPC modules.

    Parameters
    ----------
    mode : int or spcm.DLLOperationMode
        The mode in which to initialize the SPCM DLL. Use 0 for hardware;
        special constants for simulation.

    Returns
    -------
    str
        The .ini content text.
    """
    if isinstance(mode, spcm.DLLOperationMode):
        mode = mode.value

    # The first line must be a comment starting with (whitespace followed by)
    # "SPCM", or the DLL rejects it ("Not valid configuration file"). The
    # [spc_module] section heading is not needed for spcm.init(), but it is
    # needed for the file to serve as a source_inifile for
    # spcm.save_parameters_to_inifile(), or to be read by
    # spcm.read_parameters_from_inifile().
    return f"""; SPCM
[spc_base]
simulation = {mode}
[spc_module]
"""


@contextlib.contextmanager
def ini_file(text: str) -> Iterator[str]:
    """
    Context manager providing a temporary .ini file with the given text.

    Parameters
    ----------
    text : str
        The desired contents of the .ini file.

    Yields
    ------
    str
        The path name to the temporary .ini file.
    """
    with tempfile.TemporaryDirectory() as dirname:
        ininame = os.path.join(dirname, "pybhspc.ini")
        with open(ininame, mode="w") as inifile:
            inifile.write(text)
        yield ininame
