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

lib = "/usr/local/lib/libdaqhats.so"


struct hatinfotemp
    address::UInt8 			# The board address.
    id::UInt16 				# The product ID, one of [HatIDs](@ref HatIDs)
    version::UInt16 			# The hardware version
    product_name::NTuple{256,UInt8}	# The product name (c - initialized to 256 characters)
end

struct hatinfo
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
	hat_list()
Return a list of all detected DAQ HAT boards.
Synonym for hat_list("ANY")
"""
function hat_list()
	hat_list(:ANY)	 # Match any DAQ HAT ID in hatlist()
end


"""
	hat_list(filter_id::Symbol, type::Symbol)
Return a count of detected DAQ HAT boards of specified type.
Only valid parameter for type is "Count"
"""
function hat_list(filter_id::Symbol, type::Symbol)
	if lowercase(string(type)) == "count"
		idDict, ridDict = hat_list_dict()
		# number of HATS
		count = ccall((:hat_list, "/usr/local/lib/libdaqhats"),
		Cint, (UInt16, Ptr{Cvoid}), idDict[filter_id], C_NULL)
		return count
	else
		error("only valid parameter for type is \"Count\"")
	end
end

"""
	hat_list(filter_id::Symbol)
Return a list of all detected DAQ HAT boards of specified type.
"""
function hat_list(filter_id::Symbol)
	# associate filter_id with number
	idDict, ridDict = hat_list_dict()
	# get number of HATS of specified type
	count = hat_list(filter_id, :Count)
	# get the structure of information
	list = hat_list(filter_id, count)
end


"""
	hat_list(filter_id::Symbol, number::Integer)
Return a list of detected DAQ HAT boards up to the specified number.
"""
function hat_list(filter_id::Symbol, number::Integer)
	if number < 1
		error("Number of HATS must be >= 1")
	end
	idDict, ridDict = hat_list_dict()  # dictionary of hat types

	# number of HATS installed
	numberMax = ccall((:hat_list, "/usr/local/lib/libdaqhats"),
	Cint, (UInt16, Ptr{Cvoid}), idDict[filter_id], C_NULL)

	if number <= numberMax
		# generate variables for ccall below
		listTemp = Vector{hatinfotemp}(undef,number)
		list     = Vector{hatinfo}(undef,number)
		for i = 1:number
			listTemp[i] = hatinfotemp(0, 0, 0, map(UInt8, (string(repeat(" ",256))...,)))
		end
		
		success = ccall((:hat_list, "/usr/local/lib/libdaqhats"), 
		Cint, (UInt16, Ptr{hatinfotemp}), idDict[filter_id], listTemp)
		# get only the required text from .product_name
		for i = 1:number
			a = String([listTemp[i].product_name...])
			f = findfirst(Char(0x0), a)
			p = SubString(a, 1:f-1)
			keyvalue = string(ridDict[listTemp[i].id])
			list[i] = hatinfo(listTemp[i].address, keyvalue, listTemp[i].version, p)
		end
		return list	
	else
		error("Requesting $number HATS, $numberMax HAT(S) installed")
	end
end