<!--
This file is part of pybhspc
Copyright 2024-2025 Board of Regents of the University of Wisconsin System
SPDX-License-Identifier: MIT
-->

# Developing pybhspc

## Code overview

pybhspc uses Cython to generate Python bindings for SPCM-DLL functions and
structs (`_spcm.pxd`, `spcm.pyx`). Enum constants are defined using the Python
standard library `enum` package. A few Win32 API functions are also separately
wrapped (`_win32_version.pxd`, `_file_version.pyx`) to detect the DLL version
information.

Loading the extension module `spcm` requires that `spcm64.dll` be accessible.
This is set up in the `__init__.py` of the `bh_spc` package.

The build uses setuptools and is configured in `pyproject.toml` (and `setup.py`
for building the extension modules).

Tests are run using pytest, with the `spcm` extension module also using doctest
(called by one of the pytest test cases).

Documentation is built with MkDocs, with mkdocstrings used to include the
docstrings for the API Reference. This requires a versions of the extension
modules, because the docstrings for those are extracted from the imported
modules. Usage examples use the mkdocs-jupyter plugin and are in jupytext
format; they are executed as part of the documentation build.

Nox is used to standardize and automate the "official" build and testing
process (across all the supported versions of Python).

A pre-commit hook is used to run linting, formatting, and type checking by
mypy.

At the moment mypy is unable to access the type annotations in the extension
modules. Fixing this will require generating type stubs (`.pyi`) from the
Cython source (`.pyx`) and/or the built extension modules; there does not
appear to be a stable, ready-made, and fully automated way to do this.

## Building and testing

### Requirements

Windows 10+, 64-bit Intel.

Visual Studio 2017+ (latest version recommended) with `C++ Desktop Development`
workload. Alternatively, Build Tools for Visual Studio (2017+) should also
work, but this has not been tested.

Python 3.10+.

Becker & Hickl TCSPC Package with SPCM-DLL 5.2.0 (Sep 2023, TCSPC Package 7.0)
or later (note that a more recent version is required than at run time). SPCM
DLL 5.1.0 (Dec 2022) is the theoretical minimum requirement, but its header
file `Spcm_def.h` may need to have trailing whitespace removed to compile.

### Pre-commit hook

Activate the [pre-commit](https://pre-commit.com/) hook with `pre-commit
install`.

### Building for iterative development

Run this once:

```sh
python -m venv venv                    # Create virtual environment 'venv'.
echo '*' >venv/.gitignore              # Git should ignore 'venv'.
pip install .[dev]
pip install --no-build-isolation -e .  # Editable install.
```

(`--no-build-isolation` allows for faster builds but requires build
requirements to be pre-installed.)

Then, to iterate on the code and documentation run these commands as needed:

```sh
python setup.py build_ext --inplace    # Must run if .pyx files changed.
pytest                                 # Run the tests.
mkdocs serve                           # Build and serve the docs.
```

(You could rerun the editable install instead of invoking `setup.py` to rebuild
the extension modules, but that takes longer.)

### Testing in isolated environments

```sh
pip install nox    # Also included in 'pip install .[dev]'.
nox                # Build and run the tests.
```

By default this attempts to test with every supported Python version (if
available).

### Building wheels

```sh
nox -s build
```

By default this attempts to build wheels for every supported Python version (if
available).

### Building the documentation

```sh
nox -s docs
```

Note that this builds the extension modules and the documentation in-tree.
The built documentation is in `site/`.

## Contributing to pybhspc

pybhspc is an open source project and contributions are welcome. Please create
a GitHub issue or pull request.

If you plan to propose a significant change, it is a good idea to first create
an issue to discuss the design and scope of the change.

New code should be accompanied with unit tests where practical (but this should
focus on testing pybhspc, not the behavior of SPCM-DLL). Also, new or changed
APIs should be documented. Generally, please follow the existing style and
structure of code and documentation when there is no reason not to.
