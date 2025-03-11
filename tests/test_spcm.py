# This file is part of pybhspc
# Copyright 2024 Board of Regents of the University of Wisconsin System
# SPDX-License-Identifier: MIT

import array
import copy
import doctest

import pytest

from bh_spc import dump_state, ini_file, minimal_spcm_ini, spcm


def test_doctest():
    # We are not using pytest's --doctest-modules option because it didn't
    # seem to work (for extension modules?). Instead, let's just run it here.
    fails, tests = doctest.testmod(spcm, optionflags=doctest.ELLIPSIS)
    assert tests > 0
    assert fails == 0


def test_init_status_xilinx_err():
    assert spcm.InitStatus(-100) == spcm.InitStatus.XILINX_ERR
    assert spcm.InitStatus(-142) == spcm.InitStatus.XILINX_ERR
    assert spcm.InitStatus(-199) == spcm.InitStatus.XILINX_ERR


def test_init_status_unknown():
    with pytest.raises(ValueError):
        spcm.InitStatus(1)
    with pytest.raises(ValueError):
        spcm.InitStatus(-200)


def test_init_status_message():
    assert spcm.InitStatus(0).message == "Initialized"


def test_mod_info_repr():
    mi = spcm.ModInfo()
    assert (
        repr(mi)
        == "<ModInfo(module_type=<ModuleType.UNKNOWN: 0>, bus_number=0, slot_number=0, in_use=<InUseStatus.NOT_IN_USE: 0>, init=<InitStatus.OK: 0>)>"
    )


def test_mod_info_as_dict():
    mi = spcm.ModInfo()
    assert mi.as_dict() == {
        "module_type": spcm.ModuleType(0),
        "bus_number": 0,
        "slot_number": 0,
        "in_use": spcm.InUseStatus(0),
        "init": spcm.InitStatus(0),
    }


def test_par_id():
    assert spcm.ParID.CFD_LIMIT_LOW.value == 0
    assert spcm.ParID.CFD_LIMIT_LOW.type is float
    assert spcm.ParID.MODE.value == 27
    assert spcm.ParID.MODE.type is int


def test_spc_data_copy():
    d0 = spcm.Data()
    assert d0.cfd_limit_low != 4.5  # Premise of test
    d0.cfd_limit_low = 4.5
    d1 = copy.copy(d0)
    assert d1.cfd_limit_low == 4.5


def test_spc_data_deep_copy():
    d0 = spcm.Data()
    d0.cfd_limit_low = 4.5
    d1 = copy.deepcopy(d0)
    assert d1.cfd_limit_low == 4.5


def test_spc_data_eq():
    d0 = spcm.Data()
    d1 = spcm.Data()
    assert d0 == d1
    d1.cfd_limit_low = 4.5
    assert d0 != d1
    d0.cfd_limit_low = 4.5
    assert d0 == d1


def test_spc_data_repr():
    d = spcm.Data()
    d.sync_freq_div = 2
    r = repr(d)
    assert r.startswith("<Data(")
    assert r.endswith(")>")
    assert ", sync_freq_div=2, " in r


def test_spc_data_as_dict():
    d = spcm.Data()
    d.sync_freq_div = 2
    dct = d.as_dict()
    assert "sync_freq_div" in dct
    assert dct["sync_freq_div"] == 2


def test_spc_data_diff_as_dict():
    d0 = spcm.Data()
    d1 = spcm.Data()
    d1.sync_freq_div = 2
    diff = d1.diff_as_dict(d0)
    assert len(diff) == 1
    assert diff["sync_freq_div"] == 2


def test_spc_data_fields():
    # Mostly test that we do not have any typos that cause the field getters
    # and setters to not match.
    for f in spcm.Data._fields:
        d = spcm.Data()
        assert float(getattr(d, f)) == 0.0
        setattr(d, f, 1)
        assert float(getattr(d, f)) == 1.0
        assert float(d.as_dict()[f]) == 1.0


def test_spc_data_fields_match_par_ids():
    pids = [pid.name.lower() for pid in spcm.ParID]
    fields = [k for k, v in spcm.Data().items()]
    assert pids == fields


def test_adjust_para_repr():
    r = repr(spcm.AdjustPara())
    assert r.startswith("<AdjustPara(")
    assert r.endswith(")>")
    assert ", vrt2=0, " in r


def test_adjust_para_as_dict():
    d = spcm.AdjustPara().as_dict()
    assert "vrt1" in d
    assert d["vrt1"] == 0


def test_eep_data_repr():
    r = repr(spcm.EEPData())
    assert r.startswith("<EEPData(")
    assert r.endswith(")>")
    assert ", serial_no='', " in r


def test_eep_data_as_dict():
    d = spcm.EEPData().as_dict()
    assert "date" in d
    assert d["date"] == ""
    assert d["adj_para"].as_dict()["sync_div"] == 0


def test_rate_values_repr():
    r = repr(spcm.RateValues())
    assert r.startswith("<RateValues(")
    assert r.endswith(")>")
    assert ", cfd_rate=0.0, " in r


def test_rate_values_as_dict():
    d = spcm.RateValues().as_dict()
    assert "tac_rate" in d
    assert d["tac_rate"] == 0.0


def test_measurement_state_bh_name():
    assert spcm.measurement_state_bh_name("FIFO_OVERFLOW") == "SPC_FOVFL"
    assert spcm.measurement_state_bh_name("SEQUENCER_GAP") == "SPC_SEQ_GAP"


def test_get_error_string():
    assert spcm.get_error_string(0) == "No error"
    assert spcm.get_error_string(spcm.ErrorEnum.NONE) == "No error"
    assert "file" in spcm.get_error_string(-1).lower()
    with pytest.raises(OverflowError):
        spcm.get_error_string(32768)
    assert spcm.get_error_string(spcm.ErrorEnum.UNKNOWN).startswith("Unknown ")


def test_init_close():
    with ini_file(minimal_spcm_ini(150)) as ininame:
        spcm.init(ininame)  # Simulated should always succeed.
    spcm.close()


def test_failed_init():
    with (
        ini_file("invalid") as ininame,
        pytest.raises(spcm.SPCMError) as exc_info,
    ):
        spcm.init(ininame)
    assert exc_info.value.enum == spcm.ErrorEnum.FILE_NVALID


def test_get_init_status(init_spc150):
    assert spcm.get_init_status(0) == spcm.InitStatus.OK
    with pytest.raises(spcm.SPCMError) as exc_info:
        spcm.get_init_status(1000)
    assert exc_info.value.enum == spcm.ErrorEnum.MOD_NO


def test_get_mode(init_spc150):
    assert spcm.get_mode() == spcm.DLLOperationMode.SIMULATE_SPC_150
    # Would be good to also test that SPCMError is raised when not initialized,
    # but the uninitialized state cannot be reproduced with
    # SPC_close() (so we would need to test in a dedicated fresh process).


def test_set_mode(init_spc150):
    spcm.set_mode(spcm.DLLOperationMode.SIMULATE_SPC_180N, False, (True,))
    assert spcm.get_mode() == spcm.DLLOperationMode.SIMULATE_SPC_180N
    assert spcm.get_init_status(0) == spcm.InitStatus.OK
    assert spcm.get_init_status(1) == spcm.InitStatus.NOT_DONE
    assert spcm.get_init_status(7) == spcm.InitStatus.NOT_DONE


def test_test_id(init_spc150):
    assert spcm.test_id(0) == spcm.ModuleType.SPC_150


def test_test_id_error():
    with pytest.raises(spcm.SPCMError) as exc_info:
        spcm.test_id(100)
    assert exc_info.value.enum == spcm.ErrorEnum.MOD_NO


def test_get_module_info(init_spc150):
    info = spcm.get_module_info(0)
    assert info.module_type == spcm.ModuleType.SPC_150
    assert info.in_use == spcm.InUseStatus.IN_USE_HERE
    assert info.init == spcm.InitStatus.OK


def test_disabled_module(init_spc150):
    spcm.set_mode(spcm.DLLOperationMode.SIMULATE_SPC_150, False, (True,))
    info = spcm.get_module_info(1)
    assert info.module_type == spcm.ModuleType.SPC_150
    assert info.in_use == spcm.InUseStatus.NOT_IN_USE
    assert info.init == spcm.InitStatus.NOT_DONE


def test_disabling_all_modules_raises(init_spc150):
    with pytest.raises(spcm.SPCMError) as exc_info:
        spcm.set_mode(spcm.DLLOperationMode.SIMULATE_SPC_150, False, ())
    assert exc_info.value.enum == spcm.ErrorEnum.NO_ACT_MOD


def test_get_version(init_spc150):
    # We assume simulated modules return 0 as version. Don't know if this is
    # always the case.
    assert spcm.get_version(0) == "0"


def test_get_set_parameters(init_spc150):
    # For now, just test that it works.
    p = spcm.get_parameters(0)
    spcm.set_parameters(0, p)


def test_get_parameter(init_spc150):
    cfdll = spcm.get_parameter(0, spcm.ParID.CFD_LIMIT_LOW)
    assert isinstance(cfdll, float)
    assert cfdll == spcm.get_parameters(0).cfd_limit_low

    mode = spcm.get_parameter(0, spcm.ParID.MODE)
    assert isinstance(mode, int)
    assert mode == spcm.get_parameters(0).mode


def test_set_parameter(init_spc150):
    spcm.set_parameter(0, spcm.ParID.CFD_LIMIT_LOW, -10.0)
    assert spcm.get_parameter(0, spcm.ParID.CFD_LIMIT_LOW) == pytest.approx(
        -10.0, abs=0.5
    )

    spcm.set_parameter(0, spcm.ParID.MODE, 1)
    assert spcm.get_parameter(0, spcm.ParID.MODE) == 1

    with pytest.raises(TypeError):
        spcm.set_parameter(0, spcm.ParID.MODE, 1.0)


def test_get_parameter_parameters(init_spc150):
    # Have some chance of catching incorrect numbering or typing of ParID
    # members.
    p = spcm.get_parameters(0)
    for par_id in spcm.ParID:
        v = spcm.get_parameter(0, par_id)
        field = par_id.name.lower()
        vv = getattr(p, field)
        assert type(v) is par_id.type
        assert par_id.type is type(vv)
        assert v == vv


def test_get_eeprom_data(init_spc150):
    d = spcm.get_eeprom_data(0)
    assert d.module_type == "SPC-150"


def test_get_adjust_parameters(init_spc150):
    ap = spcm.get_adjust_parameters(0)
    d = spcm.get_eeprom_data(0)
    assert ap.vrt1 == d.adj_para.vrt1


def test_read_parameters_from_inifile(init_spc150):
    with ini_file(minimal_spcm_ini(150)) as ininame:
        p = spcm.read_parameters_from_inifile(ininame)
    assert p.add_select == 0  # Default value.


def test_save_parameters_to_inifile(init_spc150, tmp_path):
    test_ini = tmp_path / "test.ini"
    p = spcm.Data()
    # Since we initialized with a temporary INI file that no longer exists, we
    # need to specify a source_inifile that exists during the call.
    with ini_file(minimal_spcm_ini(150)) as ininame:
        spcm.save_parameters_to_inifile(
            p, str(test_ini), source_inifile=ininame
        )

    pp = spcm.read_parameters_from_inifile(str(test_ini))
    # Default would be ~ -19.6, but zero should have been saved.
    assert pp.sync_threshold == 0.0

    # It's not clear exactly what requirements are imposed on source_inifile
    # when with_comments=True, but it does seem to work on files containing all
    # the parameters from a previous save.
    test2_ini = tmp_path / "test2.ini"
    spcm.save_parameters_to_inifile(
        p, str(test2_ini), source_inifile=str(test_ini), with_comments=True
    )


def test_test_state(init_spc150):
    assert spcm.MeasurementState.ARMED not in spcm.test_state(0)


def test_get_sync_state(init_spc150):
    # Presumably a good assumption for the simulator.
    assert spcm.SyncState.SYNC_OVERLOAD not in spcm.get_sync_state(0)


def test_get_time_from_start(init_spc150):
    assert spcm.get_time_from_start(0) >= 0.0


def test_get_break_time(init_spc150):
    assert spcm.get_break_time(0) >= 0.0


def test_get_actual_coltime(init_spc150):
    assert spcm.get_actual_coltime(0) >= 0.0


def test_clear_read_rates(init_spc150):
    spcm.clear_rates(0)
    # With hardware, we could get None if we read the rates before they are
    # ready. With the simulator this behavior has not been observed.
    assert spcm.read_rates(0).sync_rate > 0.0  # Assume simulator behavior.


def test_get_fifo_usage(init_spc150):
    spcm.set_parameter(0, spcm.ParID.MODE, 1)  # FIFO
    assert spcm.get_fifo_usage(0) == 0.0


def test_start_stop_measurement(init_spc150):
    spcm.set_parameter(0, spcm.ParID.MODE, 1)  # FIFO
    spcm.set_parameter(0, spcm.ParID.STOP_ON_TIME, 0)
    assert spcm.MeasurementState.ARMED not in spcm.test_state(0)
    spcm.start_measurement(0)
    assert spcm.MeasurementState.ARMED in spcm.test_state(0)
    spcm.stop_measurement(0)
    assert spcm.MeasurementState.ARMED not in spcm.test_state(0)


def test_read_fifo(init_spc150):
    spcm.set_parameter(0, spcm.ParID.MODE, 1)  # FIFO
    spcm.set_parameter(0, spcm.ParID.COLLECT_TIME, 0.01)
    spcm.set_parameter(0, spcm.ParID.STOP_ON_TIME, 1)
    spcm.start_measurement(0)
    buf = array.array("H", (0 for _ in range(1024)))
    words_read = 0
    n = 1
    while spcm.MeasurementState.ARMED in spcm.test_state(0) or n > 0:
        n = spcm.read_fifo(0, buf)
        words_read += n
    spcm.stop_measurement(0)
    assert words_read > 0


def test_read_fifo_to_array(init_spc150):
    spcm.set_parameter(0, spcm.ParID.MODE, 1)  # FIFO
    spcm.set_parameter(0, spcm.ParID.COLLECT_TIME, 0.01)
    spcm.set_parameter(0, spcm.ParID.STOP_ON_TIME, 1)
    spcm.start_measurement(0)
    words_read = 0
    n = 1
    while spcm.MeasurementState.ARMED in spcm.test_state(0) or n > 0:
        data = spcm.read_fifo_to_array(0, 1024)
        n = len(data)
        words_read += n
    spcm.stop_measurement(0)
    assert words_read > 0


def test_get_fifo_init_vars(init_spc150):
    spcm.set_parameter(0, spcm.ParID.MODE, 1)  # FIFO
    spcm.set_parameter(0, spcm.ParID.MACRO_TIME_CLK, 0)  # 25 ns
    v = spcm.get_fifo_init_vars(0)
    assert v.fifo_type == spcm.FIFOType.SPC_150
    assert spcm.StreamType.HAS_SPC_HEADER in v.stream_type
    assert v.mt_clock == 250

    # SPC header in SPC-150 format.
    assert len(v.spc_header) == 4
    # Bytes 0-2: mt_clock
    assert v.spc_header[0] == 250
    assert v.spc_header[1] == 0
    assert v.spc_header[2] == 0
    # Byte 3: Bits 3-6: number of routing bits (4); bit 7: always 1
    assert v.spc_header[3] == (4 << 3) | (1 << 7)


def test_dump_state(init_spc150):
    dump_state()
