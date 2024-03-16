# This file is part of pybhspc
# Copyright 2024 Board of Regents of the University of Wisconsin System
# SPDX-License-Identifier: MIT

cdef extern from "Spcm_def.h":
    ctypedef struct SPCModInfo:
        short module_type
        short bus_number
        short slot_number
        short in_use
        short init
        # Ignore base_adr

    short SPC_get_error_string(
        short error_id, char *dest_string, short max_length
    )

    short SPC_init(char *ini_file)
    short SPC_close()

    short SPC_get_init_status(short mod_no)
    short SPC_get_mode()
    short SPC_set_mode(short mode, short force_use, int *use)
    short SPC_get_module_info(short mod_no, SPCModInfo *mod_info)
    short SPC_get_version(short mod_no, short *version)
