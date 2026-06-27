
@cenum TriggerMode::UInt32 begin
    TRIG_RISING_EDGE = 0
    TRIG_FALLING_EDGE = 1
    TRIG_ACTIVE_HIGH = 2
    TRIG_ACTIVE_LOW = 3
end

@cenum SourceType::UInt8 begin
    SOURCE_LOCAL = 0
    SOURCE_MASTER = 1
    SOURCE_SLAVE = 2
end

@cenum Options::UInt32 begin
	OPTS_DEFAULT = 0x0000         # Default behavior.
	OPTS_NOSCALEDATA = 0x0001     # Read / write unscaled data.
	OPTS_NOCALIBRATEDATA = 0x0002 # Read / write uncalibrated data.
	OPTS_EXTCLOCK = 0x0004        # Use an external clock source. (Not supported for mcc172)
	OPTS_EXTTRIGGER = 0x0008      # Use an external trigger source.
	OPTS_CONTINUOUS = 0x0010      # Run until explicitly stopped.
end

struct Status
    hardwareoverrun::Bool
    bufferoverrun::Bool
    triggered::Bool
    running::Bool
end

"""
	function printError(resultcode)

Print error code text from error code number
"""
function printError(resultcode)
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
