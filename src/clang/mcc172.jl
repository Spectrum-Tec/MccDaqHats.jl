module Mcc172

using CEnum

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

# exports
const PREFIXES = ["mcc172"]
for name in names(@__MODULE__; all=true), prefix in PREFIXES
    if startswith(string(name), prefix)
        @eval export $name
    end
end

end # module
