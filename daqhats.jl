module daqhats

using CEnum

struct MCC118DeviceInfo
    NUM_AI_CHANNELS::UInt8
    AI_MIN_CODE::UInt16
    AI_MAX_CODE::UInt16
    AI_MIN_VOLTAGE::Cdouble
    AI_MAX_VOLTAGE::Cdouble
    AI_MIN_RANGE::Cdouble
    AI_MAX_RANGE::Cdouble
end

function mcc118_open(address)
    ccall((:mcc118_open, libdaqhats.so), Cint, (UInt8,), address)
end

function mcc118_is_open(address)
    ccall((:mcc118_is_open, libdaqhats.so), Cint, (UInt8,), address)
end

function mcc118_close(address)
    ccall((:mcc118_close, libdaqhats.so), Cint, (UInt8,), address)
end

function mcc118_info()
    ccall((:mcc118_info, libdaqhats.so), Ptr{MCC118DeviceInfo}, ())
end

function mcc118_blink_led(address, count)
    ccall((:mcc118_blink_led, libdaqhats.so), Cint, (UInt8, UInt8), address, count)
end

function mcc118_firmware_version(address, version, boot_version)
    ccall((:mcc118_firmware_version, libdaqhats.so), Cint, (UInt8, Ptr{UInt16}, Ptr{UInt16}), address, version, boot_version)
end

function mcc118_serial(address, buffer)
    ccall((:mcc118_serial, libdaqhats.so), Cint, (UInt8, Ptr{Cchar}), address, buffer)
end

function mcc118_calibration_date(address, buffer)
    ccall((:mcc118_calibration_date, libdaqhats.so), Cint, (UInt8, Ptr{Cchar}), address, buffer)
end

function mcc118_calibration_coefficient_read(address, channel, slope, offset)
    ccall((:mcc118_calibration_coefficient_read, libdaqhats.so), Cint, (UInt8, UInt8, Ptr{Cdouble}, Ptr{Cdouble}), address, channel, slope, offset)
end

function mcc118_calibration_coefficient_write(address, channel, slope, offset)
    ccall((:mcc118_calibration_coefficient_write, libdaqhats.so), Cint, (UInt8, UInt8, Cdouble, Cdouble), address, channel, slope, offset)
end

function mcc118_a_in_read(address, channel, options, value)
    ccall((:mcc118_a_in_read, libdaqhats.so), Cint, (UInt8, UInt8, UInt32, Ptr{Cdouble}), address, channel, options, value)
end

function mcc118_trigger_mode(address, mode)
    ccall((:mcc118_trigger_mode, libdaqhats.so), Cint, (UInt8, UInt8), address, mode)
end

function mcc118_a_in_scan_actual_rate(channel_count, sample_rate_per_channel, actual_sample_rate_per_channel)
    ccall((:mcc118_a_in_scan_actual_rate, libdaqhats.so), Cint, (UInt8, Cdouble, Ptr{Cdouble}), channel_count, sample_rate_per_channel, actual_sample_rate_per_channel)
end

function mcc118_a_in_scan_start(address, channel_mask, samples_per_channel, sample_rate_per_channel, options)
    ccall((:mcc118_a_in_scan_start, libdaqhats.so), Cint, (UInt8, UInt8, UInt32, Cdouble, UInt32), address, channel_mask, samples_per_channel, sample_rate_per_channel, options)
end

function mcc118_a_in_scan_buffer_size(address, buffer_size_samples)
    ccall((:mcc118_a_in_scan_buffer_size, libdaqhats.so), Cint, (UInt8, Ptr{UInt32}), address, buffer_size_samples)
end

function mcc118_a_in_scan_status(address, status, samples_per_channel)
    ccall((:mcc118_a_in_scan_status, libdaqhats.so), Cint, (UInt8, Ptr{UInt16}, Ptr{UInt32}), address, status, samples_per_channel)
end

function mcc118_a_in_scan_read(address, status, samples_per_channel, timeout, buffer, buffer_size_samples, samples_read_per_channel)
    ccall((:mcc118_a_in_scan_read, libdaqhats.so), Cint, (UInt8, Ptr{UInt16}, Int32, Cdouble, Ptr{Cdouble}, UInt32, Ptr{UInt32}), address, status, samples_per_channel, timeout, buffer, buffer_size_samples, samples_read_per_channel)
end

function mcc118_a_in_scan_stop(address)
    ccall((:mcc118_a_in_scan_stop, libdaqhats.so), Cint, (UInt8,), address)
end

function mcc118_a_in_scan_cleanup(address)
    ccall((:mcc118_a_in_scan_cleanup, libdaqhats.so), Cint, (UInt8,), address)
end

function mcc118_a_in_scan_channel_count(address)
    ccall((:mcc118_a_in_scan_channel_count, libdaqhats.so), Cint, (UInt8,), address)
end

function mcc118_test_clock(address, mode, value)
    ccall((:mcc118_test_clock, libdaqhats.so), Cint, (UInt8, UInt8, Ptr{UInt8}), address, mode, value)
end

function mcc118_test_trigger(address, state)
    ccall((:mcc118_test_trigger, libdaqhats.so), Cint, (UInt8, Ptr{UInt8}), address, state)
end

@cenum AnalogInputMode::UInt32 begin
    A_IN_MODE_SE = 0
    A_IN_MODE_DIFF = 1
end

@cenum AnalogInputRange::UInt32 begin
    A_IN_RANGE_BIP_10V = 0
    A_IN_RANGE_BIP_5V = 1
    A_IN_RANGE_BIP_2V = 2
    A_IN_RANGE_BIP_1V = 3
end

struct MCC128DeviceInfo
    NUM_AI_MODES::UInt8
    NUM_AI_CHANNELS::NTuple{2, UInt8}
    AI_MIN_CODE::UInt16
    AI_MAX_CODE::UInt16
    NUM_AI_RANGES::UInt8
    AI_MIN_VOLTAGE::NTuple{4, Cdouble}
    AI_MAX_VOLTAGE::NTuple{4, Cdouble}
    AI_MIN_RANGE::NTuple{4, Cdouble}
    AI_MAX_RANGE::NTuple{4, Cdouble}
end

function mcc128_open(address)
    ccall((:mcc128_open, libdaqhats.so), Cint, (UInt8,), address)
end

function mcc128_is_open(address)
    ccall((:mcc128_is_open, libdaqhats.so), Cint, (UInt8,), address)
end

function mcc128_close(address)
    ccall((:mcc128_close, libdaqhats.so), Cint, (UInt8,), address)
end

function mcc128_info()
    ccall((:mcc128_info, libdaqhats.so), Ptr{MCC128DeviceInfo}, ())
end

function mcc128_blink_led(address, count)
    ccall((:mcc128_blink_led, libdaqhats.so), Cint, (UInt8, UInt8), address, count)
end

function mcc128_firmware_version(address, version)
    ccall((:mcc128_firmware_version, libdaqhats.so), Cint, (UInt8, Ptr{UInt16}), address, version)
end

function mcc128_serial(address, buffer)
    ccall((:mcc128_serial, libdaqhats.so), Cint, (UInt8, Ptr{Cchar}), address, buffer)
end

function mcc128_calibration_date(address, buffer)
    ccall((:mcc128_calibration_date, libdaqhats.so), Cint, (UInt8, Ptr{Cchar}), address, buffer)
end

function mcc128_calibration_coefficient_read(address, range, slope, offset)
    ccall((:mcc128_calibration_coefficient_read, libdaqhats.so), Cint, (UInt8, UInt8, Ptr{Cdouble}, Ptr{Cdouble}), address, range, slope, offset)
end

function mcc128_calibration_coefficient_write(address, range, slope, offset)
    ccall((:mcc128_calibration_coefficient_write, libdaqhats.so), Cint, (UInt8, UInt8, Cdouble, Cdouble), address, range, slope, offset)
end

function mcc128_a_in_mode_write(address, mode)
    ccall((:mcc128_a_in_mode_write, libdaqhats.so), Cint, (UInt8, UInt8), address, mode)
end

function mcc128_a_in_mode_read(address, mode)
    ccall((:mcc128_a_in_mode_read, libdaqhats.so), Cint, (UInt8, Ptr{UInt8}), address, mode)
end

function mcc128_a_in_range_write(address, range)
    ccall((:mcc128_a_in_range_write, libdaqhats.so), Cint, (UInt8, UInt8), address, range)
end

function mcc128_a_in_range_read(address, range)
    ccall((:mcc128_a_in_range_read, libdaqhats.so), Cint, (UInt8, Ptr{UInt8}), address, range)
end

function mcc128_a_in_read(address, channel, options, value)
    ccall((:mcc128_a_in_read, libdaqhats.so), Cint, (UInt8, UInt8, UInt32, Ptr{Cdouble}), address, channel, options, value)
end

function mcc128_trigger_mode(address, mode)
    ccall((:mcc128_trigger_mode, libdaqhats.so), Cint, (UInt8, UInt8), address, mode)
end

function mcc128_a_in_scan_actual_rate(channel_count, sample_rate_per_channel, actual_sample_rate_per_channel)
    ccall((:mcc128_a_in_scan_actual_rate, libdaqhats.so), Cint, (UInt8, Cdouble, Ptr{Cdouble}), channel_count, sample_rate_per_channel, actual_sample_rate_per_channel)
end

function mcc128_a_in_scan_queue_start(address, queue_count, queue, samples_per_channel, sample_rate_per_channel, options)
    ccall((:mcc128_a_in_scan_queue_start, libdaqhats.so), Cint, (UInt8, UInt8, Ptr{UInt8}, UInt32, Cdouble, UInt32), address, queue_count, queue, samples_per_channel, sample_rate_per_channel, options)
end

function mcc128_a_in_scan_start(address, channel_mask, samples_per_channel, sample_rate_per_channel, options)
    ccall((:mcc128_a_in_scan_start, libdaqhats.so), Cint, (UInt8, UInt8, UInt32, Cdouble, UInt32), address, channel_mask, samples_per_channel, sample_rate_per_channel, options)
end

function mcc128_a_in_scan_buffer_size(address, buffer_size_samples)
    ccall((:mcc128_a_in_scan_buffer_size, libdaqhats.so), Cint, (UInt8, Ptr{UInt32}), address, buffer_size_samples)
end

function mcc128_a_in_scan_status(address, status, samples_per_channel)
    ccall((:mcc128_a_in_scan_status, libdaqhats.so), Cint, (UInt8, Ptr{UInt16}, Ptr{UInt32}), address, status, samples_per_channel)
end

function mcc128_a_in_scan_read(address, status, samples_per_channel, timeout, buffer, buffer_size_samples, samples_read_per_channel)
    ccall((:mcc128_a_in_scan_read, libdaqhats.so), Cint, (UInt8, Ptr{UInt16}, Int32, Cdouble, Ptr{Cdouble}, UInt32, Ptr{UInt32}), address, status, samples_per_channel, timeout, buffer, buffer_size_samples, samples_read_per_channel)
end

function mcc128_a_in_scan_stop(address)
    ccall((:mcc128_a_in_scan_stop, libdaqhats.so), Cint, (UInt8,), address)
end

function mcc128_a_in_scan_cleanup(address)
    ccall((:mcc128_a_in_scan_cleanup, libdaqhats.so), Cint, (UInt8,), address)
end

function mcc128_a_in_scan_channel_count(address)
    ccall((:mcc128_a_in_scan_channel_count, libdaqhats.so), Cint, (UInt8,), address)
end

function mcc128_test_clock(address, mode, value)
    ccall((:mcc128_test_clock, libdaqhats.so), Cint, (UInt8, UInt8, Ptr{UInt8}), address, mode, value)
end

function mcc128_test_trigger(address, state)
    ccall((:mcc128_test_trigger, libdaqhats.so), Cint, (UInt8, Ptr{UInt8}), address, state)
end

struct MCC134DeviceInfo
    NUM_AI_CHANNELS::UInt8
    AI_MIN_CODE::Int32
    AI_MAX_CODE::Int32
    AI_MIN_VOLTAGE::Cdouble
    AI_MAX_VOLTAGE::Cdouble
    AI_MIN_RANGE::Cdouble
    AI_MAX_RANGE::Cdouble
end

@cenum TcTypes::UInt32 begin
    TC_TYPE_J = 0
    TC_TYPE_K = 1
    TC_TYPE_T = 2
    TC_TYPE_E = 3
    TC_TYPE_R = 4
    TC_TYPE_S = 5
    TC_TYPE_B = 6
    TC_TYPE_N = 7
    TC_DISABLED = 255
end

function mcc134_open(address)
    ccall((:mcc134_open, libdaqhats.so), Cint, (UInt8,), address)
end

function mcc134_is_open(address)
    ccall((:mcc134_is_open, libdaqhats.so), Cint, (UInt8,), address)
end

function mcc134_close(address)
    ccall((:mcc134_close, libdaqhats.so), Cint, (UInt8,), address)
end

function mcc134_info()
    ccall((:mcc134_info, libdaqhats.so), Ptr{MCC134DeviceInfo}, ())
end

function mcc134_serial(address, buffer)
    ccall((:mcc134_serial, libdaqhats.so), Cint, (UInt8, Ptr{Cchar}), address, buffer)
end

function mcc134_calibration_date(address, buffer)
    ccall((:mcc134_calibration_date, libdaqhats.so), Cint, (UInt8, Ptr{Cchar}), address, buffer)
end

function mcc134_calibration_coefficient_read(address, channel, slope, offset)
    ccall((:mcc134_calibration_coefficient_read, libdaqhats.so), Cint, (UInt8, UInt8, Ptr{Cdouble}, Ptr{Cdouble}), address, channel, slope, offset)
end

function mcc134_calibration_coefficient_write(address, channel, slope, offset)
    ccall((:mcc134_calibration_coefficient_write, libdaqhats.so), Cint, (UInt8, UInt8, Cdouble, Cdouble), address, channel, slope, offset)
end

function mcc134_tc_type_write(address, channel, type)
    ccall((:mcc134_tc_type_write, libdaqhats.so), Cint, (UInt8, UInt8, UInt8), address, channel, type)
end

function mcc134_tc_type_read(address, channel, type)
    ccall((:mcc134_tc_type_read, libdaqhats.so), Cint, (UInt8, UInt8, Ptr{UInt8}), address, channel, type)
end

function mcc134_update_interval_write(address, interval)
    ccall((:mcc134_update_interval_write, libdaqhats.so), Cint, (UInt8, UInt8), address, interval)
end

function mcc134_update_interval_read(address, interval)
    ccall((:mcc134_update_interval_read, libdaqhats.so), Cint, (UInt8, Ptr{UInt8}), address, interval)
end

function mcc134_t_in_read(address, channel, value)
    ccall((:mcc134_t_in_read, libdaqhats.so), Cint, (UInt8, UInt8, Ptr{Cdouble}), address, channel, value)
end

function mcc134_a_in_read(address, channel, options, value)
    ccall((:mcc134_a_in_read, libdaqhats.so), Cint, (UInt8, UInt8, UInt32, Ptr{Cdouble}), address, channel, options, value)
end

function mcc134_cjc_read(address, channel, value)
    ccall((:mcc134_cjc_read, libdaqhats.so), Cint, (UInt8, UInt8, Ptr{Cdouble}), address, channel, value)
end

struct MCC152DeviceInfo
    NUM_DIO_CHANNELS::UInt8
    NUM_AO_CHANNELS::UInt8
    AO_MIN_CODE::UInt16
    AO_MAX_CODE::UInt16
    AO_MIN_VOLTAGE::Cdouble
    AO_MAX_VOLTAGE::Cdouble
    AO_MIN_RANGE::Cdouble
    AO_MAX_RANGE::Cdouble
end

@cenum DIOConfigItem::UInt32 begin
    DIO_DIRECTION = 0
    DIO_PULL_CONFIG = 1
    DIO_PULL_ENABLE = 2
    DIO_INPUT_INVERT = 3
    DIO_INPUT_LATCH = 4
    DIO_OUTPUT_TYPE = 5
    DIO_INT_MASK = 6
end

function mcc152_open(address)
    ccall((:mcc152_open, libdaqhats.so), Cint, (UInt8,), address)
end

function mcc152_is_open(address)
    ccall((:mcc152_is_open, libdaqhats.so), Cint, (UInt8,), address)
end

function mcc152_close(address)
    ccall((:mcc152_close, libdaqhats.so), Cint, (UInt8,), address)
end

function mcc152_info()
    ccall((:mcc152_info, libdaqhats.so), Ptr{MCC152DeviceInfo}, ())
end

function mcc152_serial(address, buffer)
    ccall((:mcc152_serial, libdaqhats.so), Cint, (UInt8, Ptr{Cchar}), address, buffer)
end

function mcc152_a_out_write(address, channel, options, value)
    ccall((:mcc152_a_out_write, libdaqhats.so), Cint, (UInt8, UInt8, UInt32, Cdouble), address, channel, options, value)
end

function mcc152_a_out_write_all(address, options, values)
    ccall((:mcc152_a_out_write_all, libdaqhats.so), Cint, (UInt8, UInt32, Ptr{Cdouble}), address, options, values)
end

function mcc152_dio_reset(address)
    ccall((:mcc152_dio_reset, libdaqhats.so), Cint, (UInt8,), address)
end

function mcc152_dio_input_read_bit(address, channel, value)
    ccall((:mcc152_dio_input_read_bit, libdaqhats.so), Cint, (UInt8, UInt8, Ptr{UInt8}), address, channel, value)
end

function mcc152_dio_input_read_port(address, value)
    ccall((:mcc152_dio_input_read_port, libdaqhats.so), Cint, (UInt8, Ptr{UInt8}), address, value)
end

function mcc152_dio_output_write_bit(address, channel, value)
    ccall((:mcc152_dio_output_write_bit, libdaqhats.so), Cint, (UInt8, UInt8, UInt8), address, channel, value)
end

function mcc152_dio_output_write_port(address, value)
    ccall((:mcc152_dio_output_write_port, libdaqhats.so), Cint, (UInt8, UInt8), address, value)
end

function mcc152_dio_output_read_bit(address, channel, value)
    ccall((:mcc152_dio_output_read_bit, libdaqhats.so), Cint, (UInt8, UInt8, Ptr{UInt8}), address, channel, value)
end

function mcc152_dio_output_read_port(address, value)
    ccall((:mcc152_dio_output_read_port, libdaqhats.so), Cint, (UInt8, Ptr{UInt8}), address, value)
end

function mcc152_dio_int_status_read_bit(address, channel, value)
    ccall((:mcc152_dio_int_status_read_bit, libdaqhats.so), Cint, (UInt8, UInt8, Ptr{UInt8}), address, channel, value)
end

function mcc152_dio_int_status_read_port(address, value)
    ccall((:mcc152_dio_int_status_read_port, libdaqhats.so), Cint, (UInt8, Ptr{UInt8}), address, value)
end

function mcc152_dio_config_write_bit(address, channel, item, value)
    ccall((:mcc152_dio_config_write_bit, libdaqhats.so), Cint, (UInt8, UInt8, UInt8, UInt8), address, channel, item, value)
end

function mcc152_dio_config_write_port(address, item, value)
    ccall((:mcc152_dio_config_write_port, libdaqhats.so), Cint, (UInt8, UInt8, UInt8), address, item, value)
end

function mcc152_dio_config_read_bit(address, channel, item, value)
    ccall((:mcc152_dio_config_read_bit, libdaqhats.so), Cint, (UInt8, UInt8, UInt8, Ptr{UInt8}), address, channel, item, value)
end

function mcc152_dio_config_read_port(address, item, value)
    ccall((:mcc152_dio_config_read_port, libdaqhats.so), Cint, (UInt8, UInt8, Ptr{UInt8}), address, item, value)
end

struct MCC172DeviceInfo
    NUM_AI_CHANNELS::UInt8
    AI_MIN_CODE::Int32
    AI_MAX_CODE::Int32
    AI_MIN_VOLTAGE::Cdouble
    AI_MAX_VOLTAGE::Cdouble
    AI_MIN_RANGE::Cdouble
    AI_MAX_RANGE::Cdouble
end

@cenum SourceType::UInt32 begin
    SOURCE_LOCAL = 0
    SOURCE_MASTER = 1
    SOURCE_SLAVE = 2
end

function mcc172_open(address)
    ccall((:mcc172_open, libdaqhats.so), Cint, (UInt8,), address)
end

function mcc172_is_open(address)
    ccall((:mcc172_is_open, libdaqhats.so), Cint, (UInt8,), address)
end

function mcc172_close(address)
    ccall((:mcc172_close, libdaqhats.so), Cint, (UInt8,), address)
end

function mcc172_info()
    ccall((:mcc172_info, libdaqhats.so), Ptr{MCC172DeviceInfo}, ())
end

function mcc172_blink_led(address, count)
    ccall((:mcc172_blink_led, libdaqhats.so), Cint, (UInt8, UInt8), address, count)
end

function mcc172_firmware_version(address, version)
    ccall((:mcc172_firmware_version, libdaqhats.so), Cint, (UInt8, Ptr{UInt16}), address, version)
end

function mcc172_serial(address, buffer)
    ccall((:mcc172_serial, libdaqhats.so), Cint, (UInt8, Ptr{Cchar}), address, buffer)
end

function mcc172_calibration_date(address, buffer)
    ccall((:mcc172_calibration_date, libdaqhats.so), Cint, (UInt8, Ptr{Cchar}), address, buffer)
end

function mcc172_calibration_coefficient_read(address, channel, slope, offset)
    ccall((:mcc172_calibration_coefficient_read, libdaqhats.so), Cint, (UInt8, UInt8, Ptr{Cdouble}, Ptr{Cdouble}), address, channel, slope, offset)
end

function mcc172_calibration_coefficient_write(address, channel, slope, offset)
    ccall((:mcc172_calibration_coefficient_write, libdaqhats.so), Cint, (UInt8, UInt8, Cdouble, Cdouble), address, channel, slope, offset)
end

function mcc172_iepe_config_read(address, channel, config)
    ccall((:mcc172_iepe_config_read, libdaqhats.so), Cint, (UInt8, UInt8, Ptr{UInt8}), address, channel, config)
end

function mcc172_iepe_config_write(address, channel, config)
    ccall((:mcc172_iepe_config_write, libdaqhats.so), Cint, (UInt8, UInt8, UInt8), address, channel, config)
end

function mcc172_a_in_sensitivity_read(address, channel, value)
    ccall((:mcc172_a_in_sensitivity_read, libdaqhats.so), Cint, (UInt8, UInt8, Ptr{Cdouble}), address, channel, value)
end

function mcc172_a_in_sensitivity_write(address, channel, value)
    ccall((:mcc172_a_in_sensitivity_write, libdaqhats.so), Cint, (UInt8, UInt8, Cdouble), address, channel, value)
end

function mcc172_a_in_clock_config_read(address, clock_source, sample_rate_per_channel, synced)
    ccall((:mcc172_a_in_clock_config_read, libdaqhats.so), Cint, (UInt8, Ptr{UInt8}, Ptr{Cdouble}, Ptr{UInt8}), address, clock_source, sample_rate_per_channel, synced)
end

function mcc172_a_in_clock_config_write(address, clock_source, sample_rate_per_channel)
    ccall((:mcc172_a_in_clock_config_write, libdaqhats.so), Cint, (UInt8, UInt8, Cdouble), address, clock_source, sample_rate_per_channel)
end

function mcc172_trigger_config(address, source, mode)
    ccall((:mcc172_trigger_config, libdaqhats.so), Cint, (UInt8, UInt8, UInt8), address, source, mode)
end

function mcc172_a_in_scan_start(address, channel_mask, samples_per_channel, options)
    ccall((:mcc172_a_in_scan_start, libdaqhats.so), Cint, (UInt8, UInt8, UInt32, UInt32), address, channel_mask, samples_per_channel, options)
end

function mcc172_a_in_scan_buffer_size(address, buffer_size_samples)
    ccall((:mcc172_a_in_scan_buffer_size, libdaqhats.so), Cint, (UInt8, Ptr{UInt32}), address, buffer_size_samples)
end

function mcc172_a_in_scan_status(address, status, samples_per_channel)
    ccall((:mcc172_a_in_scan_status, libdaqhats.so), Cint, (UInt8, Ptr{UInt16}, Ptr{UInt32}), address, status, samples_per_channel)
end

function mcc172_a_in_scan_read(address, status, samples_per_channel, timeout, buffer, buffer_size_samples, samples_read_per_channel)
    ccall((:mcc172_a_in_scan_read, libdaqhats.so), Cint, (UInt8, Ptr{UInt16}, Int32, Cdouble, Ptr{Cdouble}, UInt32, Ptr{UInt32}), address, status, samples_per_channel, timeout, buffer, buffer_size_samples, samples_read_per_channel)
end

function mcc172_a_in_scan_stop(address)
    ccall((:mcc172_a_in_scan_stop, libdaqhats.so), Cint, (UInt8,), address)
end

function mcc172_a_in_scan_cleanup(address)
    ccall((:mcc172_a_in_scan_cleanup, libdaqhats.so), Cint, (UInt8,), address)
end

function mcc172_a_in_scan_channel_count(address)
    ccall((:mcc172_a_in_scan_channel_count, libdaqhats.so), Cint, (UInt8,), address)
end

function mcc172_test_signals_read(address, clock, sync, trigger)
    ccall((:mcc172_test_signals_read, libdaqhats.so), Cint, (UInt8, Ptr{UInt8}, Ptr{UInt8}, Ptr{UInt8}), address, clock, sync, trigger)
end

function mcc172_test_signals_write(address, mode, clock, sync)
    ccall((:mcc172_test_signals_write, libdaqhats.so), Cint, (UInt8, UInt8, UInt8, UInt8), address, mode, clock, sync)
end

@cenum HatIDs::UInt32 begin
    HAT_ID_ANY = 0
    HAT_ID_MCC_118 = 322
    HAT_ID_MCC_118_BOOTLOADER = 33090
    HAT_ID_MCC_128 = 326
    HAT_ID_MCC_134 = 323
    HAT_ID_MCC_152 = 324
    HAT_ID_MCC_172 = 325
end

@cenum ResultCode::Int32 begin
    RESULT_SUCCESS = 0
    RESULT_BAD_PARAMETER = -1
    RESULT_BUSY = -2
    RESULT_TIMEOUT = -3
    RESULT_LOCK_TIMEOUT = -4
    RESULT_INVALID_DEVICE = -5
    RESULT_RESOURCE_UNAVAIL = -6
    RESULT_COMMS_FAILURE = -7
    RESULT_UNDEFINED = -10
end

struct HatInfo
    address::UInt8
    id::UInt16
    version::UInt16
    product_name::NTuple{256, Cchar}
end

@cenum TriggerMode::UInt32 begin
    TRIG_RISING_EDGE = 0
    TRIG_FALLING_EDGE = 1
    TRIG_ACTIVE_HIGH = 2
    TRIG_ACTIVE_LOW = 3
end

function hat_list(filter_id, list)
    ccall((:hat_list, libdaqhats.so), Cint, (UInt16, Ptr{HatInfo}), filter_id, list)
end

function hat_error_message(result)
    ccall((:hat_error_message, libdaqhats.so), Ptr{Cchar}, (Cint,), result)
end

function hat_interrupt_state()
    ccall((:hat_interrupt_state, libdaqhats.so), Cint, ())
end

function hat_wait_for_interrupt(timeout)
    ccall((:hat_wait_for_interrupt, libdaqhats.so), Cint, (Cint,), timeout)
end

function hat_interrupt_callback_enable(_function, user_data)
    ccall((:hat_interrupt_callback_enable, libdaqhats.so), Cint, (Ptr{Cvoid}, Ptr{Cvoid}), _function, user_data)
end

function hat_interrupt_callback_disable()
    ccall((:hat_interrupt_callback_disable, libdaqhats.so), Cint, ())
end

const A_IN_MODE_SE_FLAG = 0x00

const A_IN_MODE_DIFF_FLAG = 0x08

const A_IN_MODE_BIT_MASK = 0x08

const A_IN_MODE_BIT_POS = 3

const A_IN_RANGE_BIP_10V_FLAG = 0x00

const A_IN_RANGE_BIP_5V_FLAG = 0x10

const A_IN_RANGE_BIP_2V_FLAG = 0x20

const A_IN_RANGE_BIP_1V_FLAG = 0x30

const A_IN_RANGE_BIT_MASK = 0x30

const A_IN_RANGE_BIT_POS = 4

const OPEN_TC_VALUE = -9999.0

const OVERRANGE_TC_VALUE = -8888.0

const COMMON_MODE_TC_VALUE = -7777.0

const MAX_NUMBER_HATS = 8

const OPTS_DEFAULT = 0x0000

const OPTS_NOSCALEDATA = 0x0001

const OPTS_NOCALIBRATEDATA = 0x0002

const OPTS_EXTCLOCK = 0x0004

const OPTS_EXTTRIGGER = 0x0008

const OPTS_CONTINUOUS = 0x0010

const STATUS_HW_OVERRUN = 0x0001

const STATUS_BUFFER_OVERRUN = 0x0002

const STATUS_TRIGGERED = 0x0004

const STATUS_RUNNING = 0x0008

# exports
const PREFIXES = ["mcc"]
for name in names(@__MODULE__; all=true), prefix in PREFIXES
    if startswith(string(name), prefix)
        @eval export $name
    end
end

end # module
