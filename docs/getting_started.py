# %% [md]
# <!--
# This file is part of pybhspc
# Copyright 2024 Board of Regents of the University of Wisconsin System
# SPDX-License-Identifier: MIT
#
# ruff: noqa: D100, I001
# -->
#
# # Getting Started
#
# At the moment pybhspc only provides low-level bindings to SPCM-DLL functions.
# Using these requires familiarizing yourself with the SPCM-DLL documentation.
#
# Here we demonstrate a basic FIFO (time tag stream) mode acquisition.

# %% [md]
# ## Setting Up
#
# First, let's import the package, and the module `spcm` (as well as a few
# others that we will use below):

# %%
import bh_spc
from bh_spc import spcm

import time
import matplotlib.pyplot as plt
import numpy as np

# %% [md]
# The first step in using the SPCM functions is to initialize the library. This
# initializes both the library itself and the available devices. Initialization
# requires an `.ini` file containing mode selection (hardware or simulator) and
# acquisition parameters.
#
# In a real acquisition, you might want to load an `.ini` file with the desired
# parameters (possibly one saved in the SPCM application). Here we will use
# pybhspc's utility functions to provide a temporary `.ini` file that does
# nothing but select the DLL operation mode (in this case simulation of
# SPC-180NX):

# %%
with bh_spc.ini_file(
    bh_spc.minimal_spcm_ini(spcm.DLLOperationMode.SIMULATE_SPC_180NX)
) as ini:
    spcm.init(ini)

# %% [md]
# To run this code with a real device, you would replace `SIMULATE_SPC_180NX`
# with `HARDWARE`.

# %% [md]
# SPCM-DLL distinguishes multiple installed SPC boards ("modules") using a
# module number ranging from 0 to 31. In simulation mode, all of these numbers
# are valid. In hardware mode, if you have a single SPC board, it should be
# module number 0. Since we will be specifying this many times, let's define a
# variable:

# %%
mod_no = 0

# %% [md]
# It is a good idea to confirm that initialization of the module was
# successful. The following will also give the reason for failure if
# initialization was unsuccessful:

# %%
spcm.get_init_status(mod_no)

# %% [md]
# ## Getting and Setting Parameters
#
# Now let's set the SPC module's mode to FIFO mode. For most non-ancient SPC
# boards, FIFO mode is mode 1 (different numbers are required for SPC-600, 630,
# and 130 (but not 130EM/IN)):

# %%
spcm.set_parameter(mod_no, spcm.ParID.MODE, 1)

# %% [md]
# Let's take a look at all the parameters:

# %%
params = spcm.get_parameters(mod_no)

for par, val in params.items():
    print(f"{par} = {val}")

# %% [md]
# Note that not all of these parameters have meaning in every SPC model, and
# many don't apply at all to FIFO mode.
#
# In an actual FIFO acquisition with hardware, you will almost certainly need
# to adjust some or all of these: `cfd_*`, `sync_*`, `tac_*`,
# `ext_latch_delay`, `collect_time`, `stop_on_time`, `dither_range`,
# `routing_mode`, `trigger`, and `macro_time_clk`. See the BH documentation and
# TCSPC Handbook for details.

# %%
# For this demonstration, we will turn off `stop_on_time`, mostly because it
# does not appear to work in simulation mode. By turning it off, running this
# example on real hardware should behave the same way.
params.stop_on_time = 0

# (Set other parameters here!)

spcm.set_parameters(mod_no, params)

# %% [md]
# It is also a good idea to read out all the parameters after making changes,
# because some parameters will be snapped to allowed values. We'll skip that
# here for brevity.

# %% [md]
# ## Acquiring Data
#
# Now let's acquire some data. In FIFO mode, it is necessary to frequently read
# out the available data during an acquisition ("measurement") so that the FIFO
# (first-in first-out) buffer of the device does not overflow (FIFO overflow
# can be detected, but that is not covered here).
#
# In this simple example, let's just run the acquisition for a short, fixed
# time (the duration is software-controlled here, so it won't be precise):

# %%
duration = 0.1  # s
buf_size = 32768  # Max number of 16-bit words in a single read.

spcm.start_measurement(mod_no)
start_time = time.monotonic()

data = []  # Collect arrays of data into a list.
while True:
    elapsed = time.monotonic() - start_time
    if elapsed >= duration:
        spcm.stop_measurement(mod_no)
        break
    buf = spcm.read_fifo_to_array(mod_no, buf_size)
    if len(buf):
        data.append(buf)
    if len(buf) < buf_size:  # We've read all there is to read.
        time.sleep(0.001)

# Make sure to read the data that arrived after stopping (if you need it).
while True:
    buf = spcm.read_fifo_to_array(mod_no, buf_size)
    if not len(buf):
        break
    data.append(buf)

# %% [md]
# `read_fifo_to_array()` returns an `array.array` of unsigned 16-bit numbers,
# but the event records are 32-bit. Numpy can be used to concatenate all the
# acquired data into a single array of 32-bit records:

# %%
records = np.concatenate(data).view(np.uint32)
len(records)

# %% [md]
# It is beyond pybhspc's job to interpret the event records. However, let's do
# a few simple things.

# %% [md]
# Bit 29 (with bit 0 being the least significant bit) is the GAP bit, which
# indicates there was a FIFO overflow. Let's make sure no overflow occurred:

# %%
had_gap = np.any(np.bitwise_and(records, 1 << 29))
print("There was {} gap".format("a" if had_gap else "no"))

# %% [md]
# Photon records have bits 31 and 28 cleared. Let's count the photons:

# %%
photons = np.extract(np.bitwise_and(records, 0b1001 << 28) == 0, records)
len(photons)

# %% [md]
# And just for fun, we can plot a histogram of the photon microtimes, which are
# the lower 12 bits of the higher 16 bits of the records (admittedly this is
# not all that interesting with the simulated data):

# %%
max_12bit = (1 << 12) - 1  # 4095
microtimes = np.bitwise_and(np.right_shift(photons, 16), max_12bit)

# Reverse the microtimes by subtracting from the max value, because the raw
# microtime is measured from photon to SYNC, not SYNC to photon.
microtimes = max_12bit - microtimes

h = plt.hist(microtimes, bins=64)
