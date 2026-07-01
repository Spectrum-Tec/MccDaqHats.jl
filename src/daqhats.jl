#module daqhats

# Global functions and data - https://mccdaq.github.io/daqhats/c.html
# HatInfo structure
# hatlist

# mcc daqhats wrapper for c function calls
# for effective development, do the following
#    using Pkg
#    Pkg.add("Revise")
#    using Revise
#    includet("~/daqhatsJulia/daqhats.jl")
#
# then modify daqhats.jl save and check in the Julia REPL

# generic format of ccall is:
# ccall((:cFuncName, "library"), funcReturnType, (tupleInputTypes), argumentsPassedIn)
# ccall automatically converts argumentPassedIn to tupleInputTypes

libdaqhats = ("libdaqhats.so")
@debug @show(libdaqhats)

@cenum HatIDs::UInt32 begin
    HAT_ID_ANY = 0
    HAT_ID_MCC_118 = 0x0142
    HAT_ID_MCC_118_BOOTLOADER = 0x8142
    HAT_ID_MCC_128 = 0x0146
    HAT_ID_MCC_134 = 0x0143
    HAT_ID_MCC_152 = 0x0144
    HAT_ID_MCC_172 = 0x0145
end

@cenum ResultCode::Int32 begin
    RESULT_resultcode = 0
    RESULT_BAD_PARAMETER = -1
    RESULT_BUSY = -2
    RESULT_TIMEOUT = -3
    RESULT_LOCK_TIMEOUT = -4
    RESULT_INVALID_DEVICE = -5
    RESULT_RESOURCE_UNAVAIL = -6
    RESULT_COMMS_FAILURE = -7
    RESULT_UNDEFINED = -10
end

@cenum TriggerMode::UInt32 begin
    TRIG_RISING_EDGE = 0
    TRIG_FALLING_EDGE = 1
    TRIG_ACTIVE_HIGH = 2
    TRIG_ACTIVE_LOW = 3
end

@cenum Options::UInt32 begin
	OPTS_DEFAULT = 0x0000         # Default behavior.
	OPTS_NOSCALEDATA = 0x0001     # Read / write unscaled data.
	OPTS_NOCALIBRATEDATA = 0x0002 # Read / write uncalibrated data.
	OPTS_EXTCLOCK = 0x0004        # Use an external clock source. (Not supported for mcc172)
	OPTS_EXTTRIGGER = 0x0008      # Use an external trigger source.
	OPTS_CONTINUOUS = 0x0010      # Run until explicitly stopped.
end

struct HatInfoTemp
    address::UInt8 						# The board address.
    id::UInt16 							# The product ID, one of [HatIDs](@ref HatIDs)
    version::UInt16 					# The hardware version
    product_name::NTuple{256, Cchar}	# The product name (initialized to 256 characters)
end

struct HatInfo
    address::UInt8 			# The board address.
    id::String 				# The product ID, one of [HatIDs](@ref HatIDs)
    version::UInt16 		# The hardware version
    product_name::String	# The product name
end

struct Status
    hardwareoverrun::Bool
    bufferoverrun::Bool
    triggered::Bool
    running::Bool
end

ridDict = Dict{UInt16, String}(         # match HAT symbol to UInt16
0x0000 => "HAT_ID_ANY",       		# Match any DAQ HAT ID in hatlist().
0x0142 => "HAT_ID_MCC_118",  		# MCC 118 ID.
0x8142 => "HAT_ID_MCC_118_BOOTLOADER",  # MCC 118 in firmware update mode ID.
0x0146 => "HAT_ID_MCC_128",  		# MCC 128 ID.
0x0143 => "HAT_ID_MCC_134",  		# MCC 134 ID.
0x0144 => "HAT_ID_MCC_152",  		# MCC 152 ID.
0x0145 => "HAT_ID_MCC_172")  		# MCC 172 ID.

struct MccError <: Exception
	code::Cint
end
const mccerror_message = Dict{Cint, String}(
		0 => "Success, no errors",
		-1 => "A parameter passed to the function was incorrect.",
		-2 => "The device is busy.",
		-3 => "There was a timeout accessing a resource.",
		-4 => "There was a timeout while obtaining a resource lock.",
		-5 => "The device at the specified address is not the correct type.",
		-6 => "A needed resource was not available.",
		-7 => "Could not communicate with the device.",
		-10 => "Some other error occurred.")
function Base.showerror(io::IO, e::MccError)
	print(io, "MccError: ", mccerror_message[e.code])
end
mcc_error(code::Integer) = any(code .!= [0, -2]) && throw(MccError(code))

"""
	function printerror(resultcode)
Print error code text from error code number (deprecated)
"""
function printerror(resultcode)
	# map resultcode to descriptive string
	resultDict = Dict{Int32, String}(
		0 => "Success, no errors",
		-1 => "A parameter passed to the function was incorrect.",
		-2 => "The device is busy.",
		-3 => "There was a timeout accessing a resource.",
		-4 => "There was a timeout while obtaining a resource lock.",
		-5 => "The device at the specified address is not the correct type.",
		-6 => "A needed resource was not available.",
		-7 => "Could not communicate with the device.",
		-10 => "Some other error occurred.")
	if resultcode != 0
		# @show(resultcode)
		error(resultDict[resultcode])
	end
end

"""
	hat_list_count(filter_id::HatIDs)
	
Count detected DAQ HAT boards.

filter_id types: ``HAT_ID_ANY, HAT_ID_MCC_118, HAT_ID_MCC_118_BOOTLOADER, 
HAT_ID_MCC_128, HAT_ID_MCC_134, HAT_ID_MCC_152. HAT_ID_MCC_172``
"""
function hat_list_count(filter_id::HatIDs)
		num = ccall((:hat_list, libdaqhats),
		Cint, (UInt16, Ptr{Cvoid}), filter_id, C_NULL)
		return num
end

"""
	hat_list([filter_id::HatIDs, [number]]; countnum = false)

Return a list of detected DAQ HAT boards.

`hat_list()` : Synonym for hat_list(HAT_ID_ANY)

`hat_list(filter_id::HatIDs)` : All detected DAQ HAT boards of specified type.

`hat_list(filter_id::HatIDs, number::Integer)` : List of detected DAQ HAT boards up to the specified number.

`filter_id types: ``HAT_ID_ANY, HAT_ID_MCC_118, HAT_ID_MCC_118_BOOTLOADER, 
HAT_ID_MCC_128, HAT_ID_MCC_134, HAT_ID_MCC_152. HAT_ID_MCC_172``
"""
function hat_list()
	hat_list(HAT_ID_ANY)	 # Match any DAQ HAT ID in hatlist()
end

function hat_list(filter_id::HatIDs)
	# get number of HATS of specified type
	number = hat_list_count(filter_id)
	# get the structure of information
	list = hat_list(filter_id, number)
	return list
end

function hat_list(filter_id::HatIDs, number::Integer)
	
	if number < 1
		error("Must have at least 1 HAT")
	end

	# number of HATS installed
	numbermax = ccall((:hat_list, libdaqhats),
	Cint, (UInt16, Ptr{Cvoid}), filter_id, C_NULL)

	if number <= numbermax
		# generate variables for ccall below
		# first use HatInfoTemp for ccall and then modify to HatInfo for use
		listtmp = Vector{HatInfoTemp}(undef,number)
		list    = Vector{HatInfo}(undef,number)
		for i = 1:number
			listtmp[i] = HatInfoTemp(0, 0, 0, map(UInt8, (string(repeat(" ",256))...,)))
			# list[i] = HatInfoTemp(0, 0, 0, map(UInt8, (string(repeat(" ",256))...,)))
		end
		
		resultcode = ccall((:hat_list, libdaqhats), 
		Cint, (UInt16, Ptr{HatInfo}), filter_id, listtmp)
		# get only the required text from .product_name
		for i = 1:number
			a = String([listtmp[i].product_name...])
			f = findfirst(Char(0x0), a)
			p = SubString(a, 1:f-1)
			keyvalue = string(ridDict[listtmp[i].id])
			list[i] = HatInfo(listtmp[i].address, keyvalue, listtmp[i].version, p)
		end
	else
		error("Requesting $number '$filter_id' HATS $numbermax installed")
	end
	return list	
end

"""
	hat_error_message(result)
Print the text of an error message
"""
function hat_error_message(result)
    msg_ptr = ccall((:hat_error_message, libdaqhats), Ptr{Cchar}, (Cint,), result)
	errormsg = unsafe_load(Ptr{Cchar}(msg_ptr))
	println(errormsg)
end

"""
	mcc_status_decode(returncode::UInt16)
This function returns a structure of the meaning of the status of the calls: mcc172_a_in_scan_status and mcc172_a_in_scan_read.  

	struct Status
		hardwareoverrun::Bool
		bufferoverrun::Bool
		triggered::Bool
		running::Bool
	end
"""
function mcc_status_decode(returncode::UInt16)
	# made return code to an Array of descriptive strings
	status = Status(returncode & 0b1 == 0b1 ? true : false,
					returncode & 0b10 == 0b10 ? true : false,
					returncode & 0b100 == 0b100 ? true : false,
					returncode & 0b1000 == 0b1000 ? true : false)
	return status
end

# The following for mcc152 only, not debugged nor exported
"""
	hat_interrupt_state()

Read the current interrupt status.

It returns the status of the interrupt signal. This signal can be shared by multiple boards so the status of each board that may generate must be read and the interrupt source(s) cleared before the interrupt will become inactive.

This function only applies when using devices that can generate an interrupt:

MCC 152
Return: 1 if interrupt is active, 0 if inactive.
"""
function hat_interrupt_state()
    st = ccall((:hat_interrupt_state, libdaqhats), Cint, ())
	return st
end

"""
	hat_wait_for_interrupt(timeout)
Wait for an interrupt to occur.

It waits for the interrupt signal to become active, with a timeout parameter.

This function only applies when using devices that can generate an interrupt:
MCC 152

Parameters: timeout – Wait timeout in milliseconds. -1 to wait forever, 0 to return immediately.

Returns: RESULT_TIMEOUT, RESULT_SUCCESS, or RESULT_UNDEFINED.
"""
function hat_wait_for_interrupt(timeout)
    resultCode = ccall((:hat_wait_for_interrupt, libdaqhats), Cint, (Cint,), timeout)
	printError(resultCode)
	return resultCode
end

function hat_interrupt_callback_enable(_function, user_data)
    ccall((:hat_interrupt_callback_enable, libdaqhats), Cint, (Ptr{Cvoid}, Ptr{Cvoid}), _function, user_data)
end

function hat_interrupt_callback_disable()
    ccall((:hat_interrupt_callback_disable, libdaqhats), Cint, ())
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
#=
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
=#

#=# exports
const PREFIXES = ["mcc"]
for name in names(@__MODULE__; all=true), prefix in PREFIXES
    if startswith(string(name), prefix)
        @eval export $name
    end
end =#

#end # module
