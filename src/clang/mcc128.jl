module Mcc128

using CEnum

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

# exports
const PREFIXES = ["mcc128"]
for name in names(@__MODULE__; all=true), prefix in PREFIXES
    if startswith(string(name), prefix)
        @eval export $name
    end
end

end # module
