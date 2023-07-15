module daqhats

using CEnum

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
