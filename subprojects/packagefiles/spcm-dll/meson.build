# This file is part of pybhspc
# Copyright 2024-2025 Board of Regents of the University of Wisconsin System
# SPDX-License-Identifier: MIT

project('spcm-dll', 'c')

# This build file simply wraps the headers and import library (.lib) binary as
# a dependency, as suggested in
# https://mesonbuild.com/Shipping-prebuilt-binaries-as-wraps.html

if host_machine.system() != 'windows' or host_machine.cpu_family() != 'x86_64'
    error('Only supports Windows x64')
endif

cc = meson.get_compiler('c')

spcm_dep = declare_dependency(
    dependencies: cc.find_library(
        'spcm64',
        dirs: meson.current_source_dir() / 'DLL/LIB/MSVC64',
    ),
    include_directories: include_directories('DLL'),
)

meson.override_dependency('spcm-dll', spcm_dep)
