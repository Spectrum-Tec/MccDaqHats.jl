
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




#=
# python utility that is probably more effort than it is worth
"""
Read scan status and data (as a list).

The analog input scan is started with :py:func:`a_in_scan_start` and
runs in the background.  This function reads the status of that
background scan and optionally reads sampled data from the scan buffer.

Args:
samples_per_channel (int): The number of samples per channel to read
from the scan buffer. Specify a negative number to return all
available samples immediately and ignore **timeout** or 0 to
only read the scan status and return no data.
timeout (float): The amount of time in seconds to wait for the
samples to be read. Specify a negative number to wait
indefinitely, or 0 to return immediately with the samples that
are already in the scan buffer (up to **samples_per_channel**.)
If the timeout is met and the specified number of samples have
not been read, then the function will return all the available
samples and the timeout status set.

Returns:
namedtuple: a namedtuple containing the following field names:

* **running** (bool): True if the scan is running, False if it has
stopped or completed.
* **hardware_overrun** (bool): True if the hardware could not
acquire and unload samples fast enough and data was lost.
* **buffer_overrun** (bool): True if the background scan buffer was
not read fast enough and data was lost.
* **triggered** (bool): True if the trigger conditions have been met
and data acquisition started.
* **timeout** (bool): True if the timeout time expired before the
specified number of samples were read.
* **data** (list of float): The data that was read from the scan
buffer.

Raises:
	HatError: A scan is not active, the board is not initialized, does
	not respond, or responds incorrectly.
	ValueError: Incorrect argument.
	"""
function mcc172_a_in_scan_read(self, samples_per_channel, timeout)
#=if not self._initialized
	raise HatError(self._address, "Not initialized.")
end=#


num_channels = mcc172_a_in_scan_channel_count(self._address)

self._lib.mcc172_a_in_scan_read.argtypes = [
	c_ubyte, POINTER(c_ushort), c_long, c_double, POINTER(c_double),
	c_ulong, POINTER(c_ulong)]

samples_read_per_channel = 0 #c_ulong(0)
samples_to_read = 0
status = 0 #c_ushort(0)
timed_out = false

if samples_per_channel < 0
	# read all available data

	# first, get the number of available samples
	samples_available = 0 #c_ulong(0)
	result, status, samples_available = mcc172_a_in_scan_status(self._address)

	#=if result != self._RESULT_SUCCESS
		raise HatError(self._address, "Incorrect response {}.".format(
			result))
	end=#

	# allocate a buffer large enough for all the data
	samples_to_read = samples_available
	buffer_size = samples_available.value * num_channels
	data_buffer = (c_double * buffer_size)()
elseif samples_per_channel == 0
	# only read the status
	samples_to_read = 0
	buffer_size = 0
	data_buffer = None
elseif samples_per_channel > 0
	# read the specified number of samples
	samples_to_read = samples_per_channel
	# create a C buffer for the read
	buffer_size = samples_per_channel * num_channels
	data_buffer = (c_double * buffer_size)()
else
	# invalid samples_per_channel
	raise ValueError("Invalid samples_per_channel $samples_per_channel")
end

result = mcc172_a_in_scan_read(
	self._address, status, samples_to_read, timeout, data_buffer,
	buffer_size, samples_read_per_channel)

if result == self._RESULT_BAD_PARAMETER
	raise ValueError("Invalid parameter.")
elseif result == self._RESULT_RESOURCE_UNAVAIL:
	raise HatError(self._address, "Scan not active.")
elseif result == self._RESULT_TIMEOUT:
	timed_out = True
elseif result != self._RESULT_SUCCESS:
	raise HatError(self._address, "Incorrect response {}.".format(
		result))
end

total_read = samples_read_per_channel.value * num_channels

# python 2 / 3 workaround for xrange
if sys.version_info.major > 2
	data_list = [data_buffer[i] for i in range(total_read)]
else
	data_list = [data_buffer[i] for i in xrange(total_read)]
end

scan_status = namedtuple(
	'MCC172ScanRead',
	['running', 'hardware_overrun', 'buffer_overrun', 'triggered',
	 'timeout', 'data'])
return scan_status(
	running=(status.value & self._STATUS_RUNNING) != 0,
	hardware_overrun=(status.value & self._STATUS_HW_OVERRUN) != 0,
	buffer_overrun=(status.value & self._STATUS_BUFFER_OVERRUN) != 0,
	triggered=(status.value & self._STATUS_TRIGGERED) != 0,
	timeout=timed_out,
	data=data_list)
end=#

# a number of functions from Python that have not been converted to Julia
#=

"""
Read the state of shared signals for testing.
	
	This function reads the state of the ADC clock, sync, and trigger
		signals. Use it in conjunction with :py:func:`a_in_clock_config_write`
		and :py:func:`trigger_config` to put the signals into slave mode then
		set values on the signals using the Raspberry Pi GPIO pins. This method
		will return the values present on those signals.
		
		Returns:
		namedtuple: a namedtuple containing the following field names:
		
		* **clock** (int): The current value of the clock signal (0 or 1).
		* **sync** (int): The current value of the sync signal (0 or 1).
		* **trigger** (int): The current value of the trigger signal
		(0 or 1).
		
		Raises:
		HatError: the board is not initialized, does not respond, or
		responds incorrectly.
		"""
function test_signals_read(self):
# if not self._initialized:
#	raise HatError(self._address, "Not initialized.")

clock = c_ubyte()
sync = c_ubyte()
trigger = c_ubyte()
result = self._lib.mcc172_test_signals_read(
	self._address, byref(clock), byref(sync), byref(trigger))
if result != self._RESULT_SUCCESS:
	raise HatError(self._address, "Incorrect response.")

test_status = namedtuple(
	'MCC172TestRead',
	['clock', 'sync', 'trigger'])
return test_status(
	clock=clock.value,
	sync=sync.value,
	trigger=trigger.value)

def test_signals_write(self, mode, clock, sync):
"""
Write values to shared signals for testing.

This function puts the shared signals into test mode and sets them to
the specified state. The signal levels can then be read on the Raspberry
Pi GPIO pins to confirm values. Return the device to normal mode when
testing is complete.

ADC conversions will not occur while in test mode. The ADCs require
synchronization after exiting test mode, so use
:py:func:`a_in_clock_config_write` to perform synchronization.

Args:
	mode (int): Set to 1 for test mode or 0 for normal mode.
	clock (int): The value to write to the clock signal in test mode
		(0 or 1).
	sync (int): The value to write to the sync signal in test mode
		(0 or 1).

Raises:
	HatError: the board is not initialized, does not respond, or
		responds incorrectly.
"""
if not self._initialized:
	raise HatError(self._address, "Not initialized.")

result = self._lib.mcc172_test_signals_write(
	self._address, mode, clock, sync)
if result != self._RESULT_SUCCESS:
	raise HatError(self._address, "Incorrect response.")
return

=#