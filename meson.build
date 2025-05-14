# This file is part of pybhspc
# Copyright 2024-2025 Board of Regents of the University of Wisconsin System
# SPDX-License-Identifier: MIT

project(
    'pybhspc',
    'c', 'cython',
    version: '0.1.1.dev0',
    meson_version: '>=1.3.0',
    default_options: [
        'b_vscrt=md',  # For Python
    ],
)

if host_machine.system() != 'windows' or host_machine.cpu_family() != 'x86_64'
    error('Only Windows x64 is supported')
endif

cc = meson.get_compiler('c')

if cc.get_id() not in ['msvc', 'clang-cl']
    error('Only MSVC or clang-cl is supported (use VS PowerShell and try setting CC)')
endif

fs = import('fs')

python = import('python').find_installation(pure: false)

spcm64_found = false

spcm64_dir_candidates = [
    get_option('spcm_dll_dir'),
]
if spcm64_dir_candidates.get(0) == ''
    spcm64_dir_candidates = [
        'C:/Program Files/Becker-Hickl/SPCM/DLL',  # Since 5.4.0
        'C:/Program Files (x86)/BH/SPCM/DLL',      # Up to 5.3.0
    ]
endif
foreach spcm64_dir : spcm64_dir_candidates
    if fs.is_dir(spcm64_dir)
        spcm64_inc = include_directories(fs.relative_to(spcm64_dir, '.'))
        spcm64_lib = cc.find_library(
            'spcm64',
            dirs: [spcm64_dir / 'LIB/MSVC64'],
            has_headers: ['Spcm_def.h'],
            header_include_directories: spcm64_inc,
            required: false,
        )
        if spcm64_lib.found()
            spcm64_dep = declare_dependency(
                dependencies: [spcm64_lib],
                include_directories: [spcm64_inc],
            )
            spcm64_found = true
            break
        endif
    endif
endforeach

if not spcm64_found # Fall back to wrap (used for CI)
    spcm64_dep = dependency('spcm-dll')
endif

win32_version_dep = cc.find_library('Version')

subdir('src/bh_spc')
