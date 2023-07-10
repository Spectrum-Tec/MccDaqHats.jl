# helper functions for mcc172

struct Status
    hardwareoverrun::Bool
    bufferoverrun::Bool
    triggered::Bool
    running::Bool
end

"""
	mcc172_status_decode(returncode::UInt16)

This function returns a structure of the meaning of the status of the calls: mcc172_a_in_scan_status and mcc172_a_in_scan_read.  

	struct Status
		hardwareoverrun::Bool 		# The board address.
		bufferoverrun::Bool 		# The product ID, one of [HatIDs](@ref HatIDs)
		triggered::Bool 			# The hardware version
		running::Bool				# The product name
	end
"""
function mcc172_status_decode(returncode::UInt16)
	# made return code to an Array of descriptive strings
	status = Status(returncode & 0b1 == 0b1 ? true : false,
					returncode & 0b10 == 0b10 ? true : false,
					returncode & 0b100 == 0b100 ? true : false,
					returncode & 0b1000 == 0b1000 ? true : false)
	return status
end

"""
	function chandict()
		
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
