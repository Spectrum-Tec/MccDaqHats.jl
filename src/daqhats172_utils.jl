
# Helper functions

#=
function success_code(s::Integer)
    # taken from daqhats.h
    if s == 0 						# RESULT_SUCCESS             = 0,
		return "Success, no errors"
    elseif s == -1					# RESULT_BAD_PARAMETER       = -1,
		return "A parameter passed to the function was incorrect."
    elseif s == -2					# RESULT_BUSY                = -2,
		return "The device is busy."
    elseif s == -3					# RESULT_TIMEOUT             = -3,
		return "There was a timeout accessing a resource."
    elseif s == -4 					# RESULT_LOCK_TIMEOUT        = -4,
		return "There was a timeout while obtaining a resource lock."
 	elseif s == -5					# RESULT_INVALID_DEVICE      = -5,
		return "The device at the specified address is not the correct type."
    elseif s == -6					# RESULT_RESOURCE_UNAVAIL    = -6,
		return "A needed resource was not available."
    elseif s == -7					# RESULT_COMMS_FAILURE       = -7,
    	return "Could not communicate with the device."
    elseif s == -10					# RESULT_UNDEFINED           = -10
		return "Some other error occurred."
	else
		return "Non C-language error"
	end
end
=#

#=
"""
	mcc172_status_decode(returncode::UInt16)
This function returns a tuple of the meaning of the status of the calls: mcc172_a_in_scan_status and mcc172_a_in_scan_read.  
"""
function mcc172_status_decode(returncode::UInt16)
	# made return code to an Array of descriptive strings
	ret = Array{String,1}()
	returncode & 0b1 == 0b1 ? push!(ret, "STATUS_HW_OVERRUN") : Nothing
	returncode & 0b10 == 0b10 ? push!(ret, "STATUS_BUFFER_OVERRUN") : Nothing
	returncode & 0b100 == 0b100 ? push!(ret, "STATUS_TRIGGERED") : Nothing
	returncode & 0b1000 == 0b1000 ? push!(ret, "STATUS_RUNNING") : Nothing
	return Tuple(ret)
end=#

struct Status
    hardwareoverrun::Bool 		# The board address.
    bufferoverrun::Bool 		# The product ID, one of [HatIDs](@ref HatIDs)
    triggered::Bool 			# The hardware version
    running::Bool				# The product name
end

"""
	mcc172_status_decode(returncode::UInt16)
This function returns a structure of the meaning of the status of the calls: mcc172_a_in_scan_status and mcc172_a_in_scan_read.  
"""
function mcc172_status_decode(returncode::UInt16)
	# made return code to an Array of descriptive strings
	status = Struct(returncode & 0b1 == 0b1 ? true : false,
					returncode & 0b10 == 0b10 ? true : false,
					returncode & 0b100 == 0b100 ? true : false,
					returncode & 0b1000 == 0b1000 ? true : false)
	return status
end

"""
function chandict
Dictionary of channel definitions (addresses)
"""
function chandict()
    chdict = Dict{Symbol, UInt8}(
        :CHAN0 => 0x01 << 0,
        :CHAN1 => 0x01 << 1,
        :CHAN2 => 0x01 << 2,
        :CHAN3 => 0x01 << 3,
        :CHAN4 => 0x01 << 4,
        :CHAN5 => 0x01 << 5,
        :CHAN6 => 0x01 << 6,
        :CHAN7 => 0x01 << 7)
end
