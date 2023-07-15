module Mcc118

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

# exports
const PREFIXES = ["mcc118"]
for name in names(@__MODULE__; all=true), prefix in PREFIXES
    if startswith(string(name), prefix)
        @eval export $name
    end
end

end # module
