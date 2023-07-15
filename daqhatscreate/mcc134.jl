module Mcc134

using CEnum

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

const OPEN_TC_VALUE = -9999.0

const OVERRANGE_TC_VALUE = -8888.0

const COMMON_MODE_TC_VALUE = -7777.0

# exports
const PREFIXES = ["mcc134"]
for name in names(@__MODULE__; all=true), prefix in PREFIXES
    if startswith(string(name), prefix)
        @eval export $name
    end
end

end # module
