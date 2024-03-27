<!--
This file is part of pybhspc
Copyright 2024 Board of Regents of the University of Wisconsin System
SPDX-License-Identifier: MIT
-->

# Developing pybhspc

## Building and testing

### Requirements

- Windows 10+, 64-bit Intel.
- Python 3.8+.
- Becker-Hickl TCSPC Package with SPCM DLL 5.1.0 (Dec 2022) or later (note that
  the required version is greater than at run time).

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

### Building the documentation

```sh
nox -s docs
```

Note that this builds the extension modules and the documentation in-tree.
The built documentation is in `site/`.
