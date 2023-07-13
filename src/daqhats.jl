#module daqhats

using CEnum

# Global functions and data - https://mccdaq.github.io/daqhats/c.html

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

# path to so library

# lib = "/usr/local/lib/libdaqhats.so" moved to src


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

struct HatInfoTemp
    address::UInt8 				# The board address.
    id::UInt16 					# The product ID, one of [HatIDs](@ref HatIDs)
    version::UInt16 			# The hardware version
    product_name::NTuple{256, Cchar}	# The product name (initialized to 256 characters)
end

struct HatInfo
    address::UInt8 			# The board address.
    id::String 				# The product ID, one of [HatIDs](@ref HatIDs)
    version::UInt16 		# The hardware version
    product_name::String	# The product name
end

ridDict = Dict{UInt16, String}(         	# match HAT symbol to UInt16
0x0000 => "HAT_ID_ANY",       				# Match any DAQ HAT ID in hatlist().
0x0142 => "HAT_ID_MCC_118",  				# MCC 118 ID.
0x8142 => "HAT_ID_MCC_118_BOOTLOADER",  	# MCC 118 in firmware update mode ID.
0x0146 => "HAT_ID_MCC_128",  				# MCC 128 ID.
0x0143 => "HAT_ID_MCC_134",  				# MCC 134 ID.
0x0144 => "HAT_ID_MCC_152",  				# MCC 152 ID.
0x0145 => "HAT_ID_MCC_172")  				# MCC 172 ID.

"""
	hat_list_count(filter_id::HatIDs)
	
Count detected DAQ HAT boards.

filter_id types: ``HAT_ID_ANY, HAT_ID_MCC_118, HAT_ID_MCC_118_BOOTLOADER, 
HAT_ID_MCC_128, HAT_ID_MCC_134, HAT_ID_MCC_152. HAT_ID_MCC_172``
"""
function hat_list_count(filter_id::HatIDs)
		num = ccall((:hat_list, "libdaqhats"),
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
function hat_list(; countnum::Bool = false)
	hat_list(HAT_ID_ANY, countnum=countnum)	 # Match any DAQ HAT ID in hatlist()
end

function hat_list(filter_id::HatIDs; countnum::Bool = false)
	# get number of HATS of specified type
	number = hat_list_count(filter_id)
	# get the structure of information
	if countnum
		return number
	end
	list = hat_list(filter_id, number; countnum=countnum)
	return list
end

function hat_list(filter_id::HatIDs, number::Integer; countnum::Bool = false)
	
	if number < 1
		error("Number of HATS must be >= 1")
	end

	# number of HATS installed
	numbermax = ccall((:hat_list, "libdaqhats"),
	Cint, (UInt16, Ptr{Cvoid}), filter_id, C_NULL)

	if countnum
		return numbermax
	end

	if number <= numbermax
		# generate variables for ccall below
		# first use HatInfoTemp for ccall and then modify to HatInfo for use
		listtmp = Vector{HatInfoTemp}(undef,number)
		list    = Vector{HatInfo}(undef,number)
		for i = 1:number
			listtmp[i] = HatInfoTemp(0, 0, 0, map(UInt8, (string(repeat(" ",256))...,)))
			# list[i] = HatInfoTemp(0, 0, 0, map(UInt8, (string(repeat(" ",256))...,)))
		end
		
		resultcode = ccall((:hat_list, "libdaqhats"), 
		Cint, (UInt16, Ptr{HatInfo}), filter_id, listtmp)
		# get only the required text from .product_name
		for i = 1:number
			a = String([listtmp[i].product_name...])
			f = findfirst(Char(0x0), a)
			p = SubString(a, 1:f-1)
			keyvalue = string(ridDict[listtmp[i].id])
			list[i] = HatInfo(listtmp[i].address, keyvalue, listtmp[i].version, p)
		end
		return list	
	else
		error("Requesting $number '$filter_id' HATS $numbermax HAT(S) installed")
	end
end

"""
	hat_error_message(result)
Print the text of an error message
"""
function hat_error_message(result)
    msg_ptr = ccall((:hat_error_message, libdaqhats.so), Ptr{Cchar}, (Cint,), result)
	errormsg = unsafe_load(Ptr{Cchar}(msg_ptr))
	println(errormsg)
end

# The following for mcc152 only, not debugged nor exported
"""
	function hat_interrupt_state()
	
		Read the current interrupt status.

		It returns the status of the interrupt signal. This signal can be shared by multiple boards so the status of each board that may generate must be read and the interrupt source(s) cleared before the interrupt will become inactive.
		
		This function only applies when using devices that can generate an interrupt:
		
		MCC 152
		Return
		1 if interrupt is active, 0 if inactive.
"""
function hat_interrupt_state()
    st = ccall((:hat_interrupt_state, libdaqhats.so), Cint, ())
	return st
end

"""
function hat_wait_for_interrupt(timeout)
"""
function hat_wait_for_interrupt(timeout)
    resultCode = ccall((:hat_wait_for_interrupt, libdaqhats.so), Cint, (Cint,), timeout)
	printError(resultCode)
	return resultCode
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