module Mcc152

using CEnum

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

# exports
const PREFIXES = ["mcc152"]
for name in names(@__MODULE__; all=true), prefix in PREFIXES
    if startswith(string(name), prefix)
        @eval export $name
    end
end

end # module
