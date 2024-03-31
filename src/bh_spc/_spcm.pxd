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

        # The following fields were added in SPCM-DLL v5.1.0. Note that listing
        # these fields means that v5.1+ is required for building, which is
        # intended.
        unsigned long tdc_control  # Overlaps former short x_axis_type
        float[4] tdc_offset

        # In SPCM-DLL v5.1+, the size of the struct is padded to 256. However,
        # do not include the 'reserve' field so that we can compile with future
        # versions of the header that may add fields (and shrink 'reserve').
        # char[56] reserve

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

    ctypedef struct rate_values:
        float sync_rate
        float cfd_rate
        float tac_rate
        float adc_rate

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
    # meaning of the parameters is not documented, so it's not clear what one
    # would do with it).

    short SPC_read_parameters_from_inifile(SPCdata *data, char *inifile)
    short SPC_save_parameters_to_inifile(
        SPCdata *data,
        char *dest_inifile,
        char *source_inifile,
        int with_comments,
    )

    short SPC_test_state(short mod_no, short *state)
    short SPC_get_sync_state(short mod_no, short *sync_state)
    short SPC_get_time_from_start(short mod_no, float *time)
    short SPC_get_break_time(short mod_no, float *time)
    short SPC_get_actual_coltime(short mod_no, float *time)
    short SPC_clear_rates(short mod_no)
    short SPC_read_rates(short mod_no, rate_values *rates)
    short SPC_get_fifo_usage(short mod_no, float *usage_degree)
    # SPC_get_scan_clk_state not applicable to FIFO mode.
    # SPC_get_sequencer_state not applicable to FIFO mode.
    # SPC_read_gap_time not applicable to FIFO mode.

    short SPC_start_measurement(short mod_no)
    short SPC_stop_measurement(short mod_no)
    # SPC_pause_measurement not applicable to FIFO mode.
    # SPC_restart_measurement not applicable to FIFO mode.
    # SPC_set_page not applicable to FIFO mode.
    # SPC_enable_sequencer not applicable to FIFO mode.

    short SPC_read_fifo(
        short mod_no, unsigned long *count, unsigned short *data
    )
    # SPC_configure_memory not applicable to FIFO mode.
    # SPC_fill_memory not applicable to FIFO mode.
    # SPC_read_data_block not applicable to FIFO mode.
    # SPC_write_data_block not applicable to FIFO mode.
    # SPC_read_data_frame not applicable to FIFO mode.
    # SPC_read_data_page not applicable to FIFO mode.
    # SPC_read_block not applicable to FIFO mode.
    # SPC_save_data_to_sdtfile not applicable to FIFO mode.

    short SPC_get_fifo_init_vars(
        short mod_no,
        short *fifo_type,
        short *stream_type,
        int *mt_clock,
        unsigned int *spc_header,
    )
    # "Stream" functions are omitted, at least for now:
    # SPC_init_phot_stream
    # SPC_close_phot_stream
    # SPC_get_photon
    # SPC_init_buf_stream
    # SPC_add_data_to_stream
    # SPC_read_fifo_to_stream
    # SPC_get_photons_from_stream
    # SPC_stream_start_condition
    # SPC_stream_stop_condition
    # SPC_stream_reset
    # SPC_get_stream_buffer_size
    # SPC_get_buffer_from_stream

    # SPC_get_detector_info not applicable to FIFO mode.

    # Functions that show up in the header but omitted here:
    # SPC_clear_mom_memory - something to do with Sutter MOM?
    # SPC_read_mom_data
    # SPC_prepare_time_gates - ???
    # SPC_get_start_offset - DPC-specific
    # DPC_fill_memory - DPC-specific
    # DPC_read_rates - DPC-specific
    # SPC_clear_status_flags - "low level"
    # SPC_convert_dpc_raw_data - DPC-specific
