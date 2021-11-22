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


struct HatInfoTemp
    address::UInt8 			# The board address.
    id::UInt16 				# The product ID, one of [HatIDs](@ref HatIDs)
    version::UInt16 			# The hardware version
    product_name::NTuple{256,UInt8}	# The product name (c - initialized to 256 characters)
end

struct HatInfo
    address::UInt8 			# The board address.
    id::String 				# The product ID, one of [HatIDs](@ref HatIDs)
    version::UInt16 		# The hardware version
    product_name::String	# The product name
end

"""
	function hat_list_dict()
This is a private function to give the dictionary for card type and card
number association.  It could be public in the future.
"""
function hat_list_dict()
	idDict = Dict{Symbol, UInt16}(         # match HAT symbol to UInt16
	:ANY                => 0,       # Match any DAQ HAT ID in hatlist().
	:MCC_118            => 0x0142,  # MCC 118 ID.
	:MCC_118_BOOTLOADER => 0x8142,  # MCC 118 in firmware update mode ID.
	:MCC_128            => 0x0146,  # MCC 128 ID.
	:MCC_134            => 0x0143,  # MCC 134 ID.
	:MCC_152            => 0x0144,  # MCC 152 ID.
	:MCC_172            => 0x0145)  # MCC 172 ID.
	
	ridDict = Dict(values(idDict) .=> keys(idDict))  # for reverse lookup
	return idDict, ridDict
end

"""
	hat_list_count(filter_id::Symbol)
	
Count detected DAQ HAT boards.
"""
function hat_list_count(filter_id::Symbol)
		idDict, ridDict = hat_list_dict()
		# number of HATS
		count = ccall((:hat_list, "libdaqhats"),
		Cint, (UInt16, Ptr{Cvoid}), idDict[filter_id], C_NULL)
		return count
end

"""
	hat_list([filter_id::Symbol, [number]]; count = false)

Return a list of detected DAQ HAT boards.

hat_list() ; Synonym for hat_list("ANY")
hat_list(filter_id::Symbol) ; All detected DAQ HAT boards of specified type.
hat_list(filter_id::Symbol, number::Integer) ; List of detected DAQ HAT boards up to the specified number.

filter_id types: ``:ANY, :MCC_118, :MCC_118_BOOTLOADER, :MCC_128, :MCC_134, :MCC_152, :MCC_172``
"""
function hat_list(; count::Bool = false)
	hat_list(:ANY, count=count)	 # Match any DAQ HAT ID in hatlist()
end

function hat_list(filter_id::Symbol; count::Bool = false)
	# associate filter_id with number
	# idDict, ridDict = hat_list_dict()
	# get number of HATS of specified type
	number = hat_list_count(filter_id)
	# get the structure of information
	if count
		return number
	end
	list = hat_list(filter_id, number, count=count)
	return list
end

function hat_list(filter_id::Symbol, number::Integer; count::Bool = false)
	
	if number < 1
		error("Number of HATS must be >= 1")
	end
	idDict, ridDict = hat_list_dict()  # dictionary of hat types

	# number of HATS installed
	numbermax = ccall((:hat_list, "libdaqhats"),
	Cint, (UInt16, Ptr{Cvoid}), idDict[filter_id], C_NULL)

	if count
		return numbermax
	end

	if number <= numbermax
		# generate variables for ccall below
		listTemp = Vector{HatInfoTemp}(undef,number)
		list     = Vector{HatInfo}(undef,number)
		for i = 1:number
			listTemp[i] = HatInfoTemp(0, 0, 0, map(UInt8, (string(repeat(" ",256))...,)))
		end
		
		success = ccall((:hat_list, "libdaqhats"), 
		Cint, (UInt16, Ptr{HatInfoTemp}), idDict[filter_id], listTemp)
		# get only the required text from .product_name
		for i = 1:number
			a = String([listTemp[i].product_name...])
			f = findfirst(Char(0x0), a)
			p = SubString(a, 1:f-1)
			keyvalue = string(ridDict[listTemp[i].id])
			list[i] = HatInfo(listTemp[i].address, keyvalue, listTemp[i].version, p)
		end
		return list	
	else
		error("Requesting $number '$filter_id' HATS $numbermax HAT(S) installed")
	end
end

