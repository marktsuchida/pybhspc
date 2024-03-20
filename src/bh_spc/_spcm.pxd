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
        unsigned short base_adr

    ctypedef struct SPCdata:
        unsigned short base_adr
        short init
        float cfd_limit_low
        float cfd_limit_high
        float cfd_zc_level
        float cfd_holdoff
        float sync_zc_level
        float sync_holdoff
        float sync_threshold
        float tac_range
        short sync_freq_div
        short tac_gain
        float tac_offset
        float tac_limit_low
        float tac_limit_high
        short adc_resolution
        short ext_latch_delay
        float collect_time
        float display_time
        float repeat_time
        short stop_on_time
        short stop_on_ovfl
        short dither_range
        short count_incr
        short mem_bank
        short dead_time_comp
        unsigned short scan_control
        short routing_mode
        float tac_enable_hold
        short pci_card_no
        unsigned short mode
        unsigned long scan_size_x
        unsigned long scan_size_y
        unsigned long scan_rout_x
        unsigned long scan_rout_y
        unsigned long scan_flyback
        unsigned long scan_borders
        unsigned short scan_polarity
        unsigned short pixel_clock
        unsigned short line_compression
        unsigned short trigger
        float pixel_time
        unsigned long ext_pixclk_div
        float rate_count_time
        short macro_time_clk
        short add_select
        short test_eep
        short adc_zoom
        unsigned long img_size_x
        unsigned long img_size_y
        unsigned long img_rout_x
        unsigned long img_rout_y
        short xy_gain
        short master_clock
        short adc_sample_delay
        short detector_type
        unsigned long chan_enable
        unsigned long chan_slope
        unsigned long chan_spec_no

        # The following fields were added in SPCM DLL v5.1.0. Note that listing
        # these fields means that v5.1+ is required for building, which is
        # intended.
        unsigned long tdc_control  # Overlaps former short x_axis_type
        float[4] tdc_offset

        # In SPCM DLL v5.1+, the size of the struct is padded to 256. However,
        # do not include the 'reserve' field so that we can compile with future
        # versions of the header that may add fields (and shrink 'reserve').
        # char reserve[56]

    ctypedef struct SPC_Adjust_Para:
        short vrt1
        short vrt2
        short vrt3
        short dith_g
        float gain_1
        float gain_2
        float gain_4
        float gain_8
        float tac_r0
        float tac_r1
        float tac_r2
        float tac_r4
        float tac_r8
        short sync_div

    ctypedef struct SPC_EEP_Data:
        char[16] module_type
        char[16] serial_no
        char[16] date
        SPC_Adjust_Para adj_para

    short SPC_get_error_string(
        short error_id, char *dest_string, short max_length
    )

    short SPC_init(char *ini_file)
    short SPC_close()

    short SPC_get_init_status(short mod_no)
    short SPC_get_mode()
    short SPC_set_mode(short mode, short force_use, int *use)
    short SPC_test_id(short mod_no)
    short SPC_get_module_info(short mod_no, SPCModInfo *mod_info)
    short SPC_get_version(short mod_no, short *version)

    short SPC_get_parameters(short mod_no, SPCdata *data)
    short SPC_set_parameters(short mod_no, SPCdata *data)
    short SPC_get_parameter(short mod_no, short par_id, float *value)
    short SPC_set_parameter(short mod_no, short par_id, float value)

    short SPC_get_eeprom_data(short mod_no, SPC_EEP_Data *eep_data)
    # Omit SPC_write_eeprom_data(): It is dangerous, requires a secret key from
    # the manufacturer, and is not usually something that ought to be done
    # programmatically.
    short SPC_get_adjust_parameters(short mod_no, SPC_Adjust_Para *adjpara)
    # Omit SPC_set_adjust_parameters(), at least for now: Although it does not
    # write to the EEPROM, its use is discouraged (and as far as I know, the
    # meaning of the parameters is not documented).
