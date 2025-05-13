# This file is part of pybhspc
# Copyright 2024-2025 Board of Regents of the University of Wisconsin System
# SPDX-License-Identifier: MIT

spcm_ext = python.extension_module(
    'spcm',
    'spcm.pyx',
    dependencies: [
        spcm64_dep,
    ],
    install: true,
    subdir: 'bh_spc',
)

file_version_ext = python.extension_module(
    '_file_version',
    '_file_version.pyx',
    dependencies: [
        win32_version_dep,
    ],
    install: true,
    subdir: 'bh_spc',
)

py_sources = files(
    '__init__.py',
    '_dump_state.py',
    '_ini_files.py',

    # Cython sources are not needed at runtime, but include for good measure.
    '_spcm.pxd',
    '_win32_version.pxd',
    'spcm.pyx',
)

python.install_sources(
    py_sources,
    subdir: 'bh_spc',
)

version_py = configure_file(
    configuration: {'VERSION': meson.project_version()},
    input: '_version.py.in',
    output: '_version.py',
    install: true,
    install_dir: python.get_install_dir() / 'bh_spc',
    install_tag: 'python-runtime',
)
