# c function documentation at https://mccdaq.github.io/daqhats/c.html

# Global functions and data - https://mccdaq.github.io/daqhats/c.html

"""
	function printError(resultCode)

Print error code text from error code number
"""
function printError(resultCode)
	# map resultCode to descriptive string
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
	if resultCode != 0
		@show(resultCode)
		error(resultDict[resultCode])
	end
end

"""
	function source_convert(source::Symbol)
Convert the source symbol to an integer after checking for validity
"""
function source_convert(source::Symbol)
	# ensure source is valid
	source_set = Set{Symbol}([:SOURCE_LOCAL, :SOURCE_MASTER, :SOURCE_SLAVE])
	if !issubset(Set{Symbol}([source]), source_set)
		error("source is $source, but must be one of $source_set")
	end
	source_dict = Dict{Symbol, UInt8}(
	:SOURCE_LOCAL  => 0, 
	:SOURCE_MASTER => 1, 
	:SOURCE_SLAVE  => 2)

	return source_dict[source]
end

"""
	function mode_convert(mode::Symbol)
Convert the mode symbol to an integer after checking for validity
"""
function mode_convert(mode::Symbol)
	# ensure trigger is valid
	mode_set = Set{Symbol}([:TRIG_RISING_EDGE, :TRIG_FALLING_EDGE, 
		:TRIG_ACTIVE_HIGH, :TRIG_ACTIVE_LOW])
	if !issubset(Set{Symbol}([mode]), mode_set)
		error("mode must be one of $mode_set")
	end

	mode_dict = Dict{Symbol, UInt8}(
	:TRIG_RISING_EDGE  => 0, 
	:TRIG_FALLING_EDGE => 1, 
	:TRIG_ACTIVE_HIGH  => 2,
	:TRIG_ACTIVE_LOW   => 3)
	return mode_dict[mode]
end

# mcc172 functions - https://mccdaq.github.io/daqhats/c.html

"""
	mcc172_open(address::Integer)
Open a connection to the MCC 172 device at the specified address.
"""
function mcc172_open(address::Integer)
	resultCode = ccall((:mcc172_open, "/usr/local/lib/libdaqhats.so"), 
	Cint, (UInt8,), address)
	printError(resultCode)
	return resultCode
end

"""
	mcc172_close(address::Integer)
Close a connection to an MCC 172 device and free allocated resources.
"""
function mcc172_close(address::Integer)
	resultCode = ccall((:mcc172_close, "/usr/local/lib/libdaqhats.so"), 
	Cint, (UInt8,), address)
	printError(resultCode)
	return resultCode
end

"""
	mcc172_is_open(address::Integer)
Check if an MCC 172 is open.

Return
1 if open, 0 if not open.
"""
function mcc172_is_open(address::Integer)
# 1 if open, 0 if not open
	resultCode = ccall((:mcc172_is_open, "/usr/local/lib/libdaqhats.so"), 
	Cint, (UInt8,), address)
end

# create struct at top level for device information
mutable struct MCC172DeviceInfo
    NUM_AI_CHANNELS::UInt8    	# The number of analog input channels. UInt8(2)
    AI_MIN_CODE::Int32			# The minimum uncalibrated ADC code. (-8,388,608 or -2^23)
    AI_MAX_CODE::Int32			# The maximum uncalibrated ADC code. (8,388,607 or 2^23-1)
    AI_VOLTAGE_MIN::Float64		# The input voltage corresponding to the minimum code. (-5V)
    AI_VOLTAGE_MAX::Float64		# The input voltage corresponding to the maximum code. (+5V - 1*LSB)
    AI_RANGE_MIN::Float64		# The minimum voltage of the input range. (-5v)
    AI_RANGE_MAX::Float64		# The maximum voltage of the input range. (+5v)
end

"""
	mcc172_info()
Return constant device information for all MCC 172s.
"""
function mcc172_info()
#   This line recalculates the data from the ccall.
#	mcc172_device_info = MCC172DeviceInfo(2, -2^23, 2^23-1, -5.0, 5.0-10/2^24, -5.0, 5.0)

	output_ptr = ccall((:mcc172_info, "/usr/local/lib/libdaqhats"), 
	Ptr{MCC172DeviceInfo}, ())
#	if output_ptr == C_NULL  # Assumed, need to check
#		throw(OutOfMemoryError())
#	end
	mcc172_device_info = unsafe_load(Ptr{MCC172DeviceInfo}(output_ptr))
	return mcc172_device_info
end

"""
	mcc172_blink_led(address::Integer, count::Integer)
Blink the LED on the MCC 172.

Passing 0 for count will result in the LED blinking continuously until 
the board is reset or mcc172_blink_led() is called again with a non-zero 
value for count.
count: The number of times to blink (0 - 255)
"""
function mcc172_blink_led(address::Integer, count::Integer)
	resultCode = ccall((:mcc172_blink_led, "/usr/local/lib/libdaqhats.so"), 
	Cint, (UInt8, UInt8), address, count)
	printError(resultCode)
end


"""
	mcc172_firmware_version(address::Integer).
Return the board firmware version.

The version will be in BCD hexadecimal with the high byte as the major 
version and low byte as minor, i.e. 0x0103 is version 1.03.
"""
function mcc172_firmware_version(address::Integer)
	version = Ref{UInt16}()
	resultCode = ccall((:mcc172_firmware_version, "/usr/local/lib/libdaqhats.so"), 
	Cint, (UInt8, Ref{Cushort}), address, version)
	printError(resultCode)
	return version[]
end

"""
	mcc172_serial(address::Integer)
Read the MCC 172 serial number.
"""
function mcc172_serial(address::Integer)
	serial = Vector{UInt8}(undef, 9)  # initialize serial
	resultCode = ccall((:mcc172_serial, "/usr/local/lib/libdaqhats.so"), 
	Cint, (UInt8, Ptr{Cchar}), address, serial)
	printError(resultCode)
	return unsafe_string(pointer(serial))
end

"""
	mcc172_calibration_date(address::Integer)
Read the MCC 172 calibration date.
Date is a string (format “YYYY-MM-DD”)
"""
function mcc172_calibration_date(address::Integer)
	# calDate = "YYYY-MM-DD"
	calDate = Vector{UInt8}(undef,11) # initialized string
	resultCode = ccall((:mcc172_calibration_date, "/usr/local/lib/libdaqhats.so"), 
	Cint, (UInt8, Ptr{Cchar}), address, calDate)
	printError(resultCode)
	# return calDate
	calDate[end] = 0
	return unsafe_string(pointer(calDate))
end

"""
	mcc172_calibration_coefficient_read(address::Integer, channel::Integer)
Read the MCC 172 calibration coefficients for a single channel.

The coefficients are applied in the library as:
calibrated_ADC_code = (raw_ADC_code - offset) * slope
"""
function mcc172_calibration_coefficient_read(address::Integer, channel::Integer)
	# calibrated_ADC_code = (raw_ADC_code - offset) * slope
	slope = offset = Ref{Cdouble}()
	resultCode = ccall((:mcc172_calibration_coefficient_read, "/usr/local/lib/libdaqhats.so"), 
	Cint, (UInt8, UInt8, Ref{Cdouble}, Ref{Cdouble}), address, channel, slope, offset)
	printError(resultCode)
	return (slope[], offset[])
end

"""
	mcc172_calibration_coefficient_write(address::Integer, channel::Integer, slope::AbstractFloat, offset::AbstractFloat)
Temporarily write the MCC 172 calibration coefficients for a single channel.

The user can apply their own calibration coefficients by writing to these 
values. The values will reset to the factory values from the EEPROM 
whenever mcc172_open() is called. This function will fail and 
return RESULT_BUSY if a scan is active when it is called.

The coefficients are applied in the library as:
calibrated_ADC_code = (raw_ADC_code - offset) * slope
"""
function mcc172_calibration_coefficient_write(address::Integer, channel::Integer, slope::AbstractFloat, offset::AbstractFloat)
	# calibrated_ADC_code = (raw_ADC_code - offset) * slope
	resultCode = ccall((:mcc172_calibration_coefficient_write, "/usr/local/lib/libdaqhats.so"), 
	Cint, (UInt8, UInt8, Cdouble, Cdouble), address, channel, slope, offset)
	printError(resultCode)
	return nothing
end

"""
	mcc172_iepe_config_read(address::Integer, channel::Integer)
Read the MCC 172 IEPE configuration for a single channel.

address: The board address (0 - 7). Board must already be opened.
channel: The channel number (0 - 1).
config: Receives the configuration for the specified channel:
0: IEPE power off
1: IEPE power on

"""
function mcc172_iepe_config_read(address::Integer, channel::Integer)
	# 0: IEPE power off; 1: IEPE power on
	config = Ref{UInt8}()
	resultCode = ccall((:mcc172_iepe_config_read, "/usr/local/lib/libdaqhats.so"), 
	Cint, (UInt8, UInt8, Ref{Cuchar}), address, channel, config)
	printError(resultCode)
	return config[]
end

"""
	mcc172_iepe_config_write(address::Integer, channel::Integer, config::Integer)
Write the MCC 172 IEPE configuration for a single channel.

Writes the new IEPE configuration for a channel. This function will fail 
and return RESULT_BUSY if a scan is active when it is called.

address: The board address (0 - 7). Board must already be opened.
channel: The channel number (0 - 1).
config: The IEPE configuration for the specified channel:
0: IEPE power off
1: IEPE power on
"""
function mcc172_iepe_config_write(address::Integer, channel::Integer, config::Integer)
	# 0: IEPE power off; 1: IEPE power on
	resultCode = ccall((:mcc172_iepe_config_write, "/usr/local/lib/libdaqhats.so"), 
	Cint, (UInt8, UInt8, UInt8), address, channel, config)
	printError(resultCode)
	return nothing
end

"""
	mcc172_a_in_sensitivity_read(address::Integer, channel::Integer)
Read the MCC 172 analog input sensitivity scaling factor for a single channel.

The sensitivity is specified in mV / engineering unit. The default value 
when opening the library is 1000, resulting in no scaling of the input voltage.
"""
function mcc172_a_in_sensitivity_read(address::Integer, channel::Integer)
	# The sensitivity is specified in mV / Engineering Unit
	sensitivity = Ref{Float64}()
	resultCode = ccall((:mcc172_a_in_sensitivity_read, "/usr/local/lib/libdaqhats.so"), 
	Cint, (UInt8, UInt8, Ref{Cdouble}), address, channel, sensitivity)
	printError(resultCode)
	return sensitivity[]
end

"""
	mcc172_a_in_sensitivity_write(address::Integer, channel::Integer, sensitivity::AbstractFloat)
Write the MCC 172 analog input sensitivity scaling factor for a single channel.

This applies a scaling factor to the analog input data so it returns 
values that are meaningful for the connected sensor.

The sensitivity is specified in mV / engineering unit. The default value 
when opening the library is 1000, resulting in no scaling of the input 
voltage. Changing this value will not change the values reported by 
mcc172_info() since it is simply sensor scaling applied to the data 
before returning it.

Examples:

A seismic sensor with a sensitivity of 10 V/g. Set the sensitivity to 
10,000 and the returned data will be in units of g.
A vibration sensor with a sensitivity of 100 mV/g. Set the sensitivity 
to 100 and the returned data will be in units of g.
This function will fail and return RESULT_BUSY if a scan is active when 
it is called.
"""
function mcc172_a_in_sensitivity_write(address::Integer, channel::Integer, sensitivity::AbstractFloat)
	# The sensitivity is specified in mV / Engineering Unit
	resultCode = ccall((:mcc172_a_in_sensitivity_write, "/usr/local/lib/libdaqhats.so"), 
	Cint, (UInt8, UInt8, Cdouble), address, channel, sensitivity)
	printError(resultCode)
	return nothing
end

"""
	mcc172_a_in_clock_config_read(address::Integer)
Read the sampling clock configuration.

This function will return the sample clock configuration and rate. If the clock is configured for local or master source, then the rate will be the internally adjusted rate set by the user. If the clock is configured for slave source, then the rate will be measured from the master clock after the synchronization period has ended. The synchronization status is also returned.

The clock source will be one of the following values:

SOURCE_LOCAL = 0: The clock is generated on this MCC 172 and not shared with other MCC 172s.
SOURCE_MASTER = 1: The clock is generated on this MCC 172 and is shared as the master clock for other MCC 172s.
SOURCE_SLAVE = 2: No clock is generated on this MCC 172, it receives its clock from the master MCC 172.
The data rate will not be valid in slave mode if synced is equal to 0. 
The device will not detect a loss of the master clock when in slave mode; 
it only monitors the clock when a sync is initiated.

Return Result code, RESULT_SUCCESS if successful
Parameters:
address: The board address (0 - 7). Board must already be opened.
clock_source: Receives the ADC clock source, one of the source type values.
sample_rate_per_channel: Receives the sample rate in samples per second per channel
synced: Receives the syncronization status (0: sync in progress, 1: sync complete)
"""
function mcc172_a_in_clock_config_read(address::Integer)
	# The clock can be SOURCE_LOCAL, SOURCE_MASTER, OR SOURCE_SLAVE
	clock_source = synced = Ref{UInt8}()
	sample_rate_per_channel = Ref{Float64}(0.0)
	resultCode = ccall((:mcc172_a_in_clock_config_read, "/usr/local/lib/libdaqhats.so"), 
	Cint, (UInt8, Ref{Cuchar}, Ref{Cdouble}, Ref{Cuchar}), 
	address, clock_source, sample_rate_per_channel, synced)
	printError(resultCode)
	return (clock_source[], sample_rate_per_channel[], synced[])
end


"""
	mcc172_a_in_clock_config_write(address::Integer, clock_source::Symbol, sample_rate_per_channel::Real)
Write the sampling clock configuration.

This function will configure the ADC sampling clock. The default 
configuration after opening the device is local mode, 51.2 KHz data rate.

The clock_source must be one of:

SOURCE_LOCAL (0): The clock is generated on this MCC 172 and not shared 
with other MCC 172s.
SOURCE_MASTER (1): The clock is generated on this MCC 172 and is shared 
as the master clock for other MCC 172s. All other MCC 172s must be 
configured for local or slave clock.
SOURCE_SLAVE (2): No clock is generated on this MCC 172, it receives its 
clock from the master MCC 172.
The ADCs will be synchronized so they sample the inputs at the same time. 
This requires 128 clock cycles before the first sample is available. 
When using a master - slave clock configuration for multiple MCC 172s 
there are additional considerations:

There should be only one master device; otherwise, you will be connecting 
multiple outputs together and could damage a device.
Configure the clock on the slave device(s) first, master last. The 
synchronization will occur when the master clock is configured, causing 
the ADCs on all the devices to be in sync.
If you change the clock configuration on one device after configuring the
 master, then the data will no longer be in sync. The devices cannot 
 detect this and will still report that they are synchronized. Always 
 write the clock configuration to all devices when modifying the configuration.
Slave devices must have a master clock source or scans will never complete.
A trigger must be used for the data streams from all devices to start 
on the same sample.
The MCC 172 can generate an ADC sampling clock equal to 51.2 kHz divided 
by an integer between 1 and 256. The data_rate_per_channel will be 
internally converted to the nearest valid rate. The actual rate can be 
read back using mcc172_a_in_clock_config_read(). When used in slave clock 
configuration, the device will measure the frequency of the incoming 
master clock after the synchronization period is complete. Calling 
mcc172_a_in_clock_config_read() after this will return the measured data rate.

Return: Result code, RESULT_SUCCESS if successful

Parameters:
address: The board address (0 - 7). Board must already be opened.
clock_source: The ADC clock source, one of the source type values.
sample_rate_per_channel: The requested sample rate in samples per second per channel
"""
function mcc172_a_in_clock_config_write(address::Integer, clock_source::Symbol, sample_rate_per_channel::Real)
	# The clock can be: :SOURCE_LOCAL, :SOURCE_MASTER, OR :SOURCE_SLAVE
	# :SOURCE_LOCAL  = 0, 
	# :SOURCE_MASTER = 1, 
	# :SOURCE_SLAVE  = 2
	# Only one master device ot damage can occur
	# Configure clock on slave devices first and master last. This will cause the ADC's on all devices to be in sync.
	# If a clock is configured after the master the devices will no longer be in sync.
	# Slave devices must have a master or scans will not complete
	# Trigger must be used to start on same sample

	clock_source_num = source_convert(clock_source)
	mcc172_a_in_clock_config_write(address, clock_source_num, sample_rate_per_channel)
end

"""
function mcc172_a_in_clock_config_write(address::Integer, clock_source::Integer, sample_rate_per_channel::Real)
see function above for help
"""
function mcc172_a_in_clock_config_write(address::Integer, clock_source::Integer, sample_rate_per_channel::Real)
	resultCode = ccall((:mcc172_a_in_clock_config_write, "/usr/local/lib/libdaqhats.so"), 
	Cint, (UInt8, UInt8, Cdouble), address, clock_source, sample_rate_per_channel)
	printError(resultCode)
	return resultCode
end

"""
	mcc172_trigger_config(address::Integer, source::Integer, mode::Symbol)
Configure the digital trigger.

The analog input scan may be configured to start saving the acquired 
data when the digital trigger is in the desired state. A single device 
trigger may also be shared with multiple boards. This command sets the 
trigger source and mode.

The trigger source must be one of:

SOURCE_LOCAL (0): The trigger terminal on this MCC 172 is used and not shared with other MCC 172s.
SOURCE_MASTER (1): The trigger terminal on this MCC 172 is used and is shared as the master trigger for other MCC 172s.
SOURCE_SLAVE (2): The trigger terminal on this MCC 172 is not used, it receives its trigger from the master MCC 172.
The trigger mode must be one of:

TRIG_RISING_EDGE: Start the scan on a rising edge of TRIG.
TRIG_FALLING_EDGE: Start the scan on a falling edge of TRIG.
TRIG_ACTIVE_HIGH: Start the scan any time TRIG is high.
TRIG_ACTIVE_LOW: Start the scan any time TRIG is low.

Due to the nature of the filtering in the A/D converters there is an 
input delay of 39 samples, so the data coming from the converters at any 
time is delayed by 39 samples from the current time. This is most 
noticeable when using a trigger - there will be approximately 39 samples 
prior to the trigger event in the captured data.

Care must be taken when using master / slave triggering; the input 
trigger signal on the master will be passed through to the slave(s), 
but the mode is set independently on each device. For example, it is 
possible for the master to trigger on the rising edge of the signal 
and the slave to trigger on the falling edge.

Return: Result code, RESULT_SUCCESS if successful.
Parameters:
address: The board address (0 - 7). Board must already be opened.
source: The trigger source, one of the source type values.
mode: The trigger mode, one of the trigger mode values.
"""
function mcc172_trigger_config(address::Integer, source::Symbol, mode::Symbol)
	source_num = source_convert(source)
	mode_num = mode_convert(mode)
	# @show(source_num, mode_num)
	
	# ADC is pretriggered by 39 samples
	resultCode = mcc172_trigger_config(address, source_num, mode_num)
	return resultCode
end

"""
	function mcc172_trigger_config(address::Integer, source::Integer, mode::Integer)
see help above for details on input parameters
"""
function mcc172_trigger_config(address::Integer, source::Integer, mode::Integer)
	# ADC is pretriggered by 39 samples
	resultCode = ccall((:mcc172_trigger_config, "/usr/local/lib/libdaqhats.so"),
	Cint, (UInt8, UInt8, UInt8), address, source, mode)
	printError(resultCode)
	return resultCode
end

"""
	mcc172_a_in_scan_start(address::Integer, channel_mask::UInt8, samples_per_channel::UInt32, options::UInt32)
Start capturing analog input data from the specified channels.

The scan runs as a separate thread from the user’s code. The function 
will allocate a scan buffer and read data from the device into that buffer. 
The user reads the data from this buffer and the scan status using the 
mcc172_a_in_scan_read() function. mcc172_a_in_scan_stop() is used to stop 
a continuous scan, or to stop a finite scan before it completes. The user 
must call mcc172_a_in_scan_cleanup() after the scan has finished and all 
desired data has been read; this frees all resources from the scan and 
allows additional scans to be performed.

The scan cannot be started until the ADCs are synchronized, so this 
function will not return until that has completed. It is best to wait 
for sync using mcc172_a_in_clock_config_read() before starting the scan.

The scan state has defined terminology:

Active: mcc172_a_in_scan_start() has been called and the device may be 
acquiring data or finished with the acquisition. The scan has not been 
cleaned up by calling mcc172_a_in_scan_cleanup(), so another scan may 
not be started.
Running: The scan is active and the device is still acquiring data. 
Certain functions will return an error because the device is busy.
The valid options are:

OPTS_NOSCALEDATA: Returns ADC code (a value between AI_MIN_CODE and AI_MAX_CODE) rather than voltage.
OPTS_NOCALIBRATEDATA: Return data without the calibration factors applied.
OPTS_EXTTRIGGER: Hold off the scan (after calling mcc172_a_in_scan_start()) until the trigger condition is met.
OPTS_CONTINUOUS: Scans continuously until stopped by the user by calling 
	mcc172_a_in_scan_stop() and writes data to a circular buffer. The 
	data must be read before being overwritten to avoid a buffer overrun 
	error. samples_per_channel is only used for buffer sizing.
The OPTS_EXTCLOCK option is not supported for this device and will return an error.

The options parameter is set to 0 or OPTS_DEFAULT for default operation, 
which is scaled and calibrated data, no trigger, and finite operation.

Multiple options may be specified by ORing the flags. For instance, 
specifying OPTS_NOSCALEDATA | OPTS_NOCALIBRATEDATA will return the values 
read from the ADC without calibration or converting to voltage.

The buffer size will be allocated as follows:

Finite mode: Total number of samples in the scan

Continuous mode (buffer size is per channel): Either samples_per_channel 
or the value in the following table, whichever is greater

Sample Rate	Buffer Size (per channel)
200-1024 S/s	1 kS
1280-10.24 kS/s	10 kS
12.8, 25.6, 51.2 kS/s	100 kS
Specifying a very large value for samples_per_channel could use too much 
of the Raspberry Pi memory. If the memory allocation fails, the function 
will return RESULT_RESOURCE_UNAVAIL. The allocation could succeed, but 
the lack of free memory could cause other problems in the Raspberry Pi. 
If you need to acquire a high number of samples then it is better to run 
the scan in continuous mode and stop it when you have acquired the 
desired amount of data. If a scan is already active this function will 
return RESULT_BUSY.

Return: Result code, 	RESULT_SUCCESS if successful, 
						RESULT_BUSY if a scan is already active.
Parameters:
address: The board address (0 - 7). Board must already be opened.
channel_mask: A bit mask of the channels to be scanned. Set each bit to 
	enable the associated channel (0x01 - 0x03.)
samples_per_channel: The number of samples to acquire for each channel 
	in the scan (finite mode,) or can be used to set a larger scan 
	buffer size than the default value (continuous mode.)
options: The options bitmask.
"""
function mcc172_a_in_scan_start(address::Integer, channel_mask::UInt8, samples_per_channel::UInt32, options::Integer)

	# start capturing analog input from selected channels in separate thread
	# see documentation at https://mccdaq.github.io/daqhats/c.html#
	# Result code, RESULT_SUCCESS if successful, RESULT_BUSY if a scan is already active.
	resultCode = ccall((:mcc172_a_in_scan_start, "/usr/local/lib/libdaqhats.so"),
	Cint, (UInt8, UInt8, UInt32, UInt32), 
	address, channel_mask, samples_per_channel, options)
	printError(resultCode)
end

"""
	function mcc172_a_in_scan_start(address::Int32, channel_mask::UInt8, samples_per_channel::UInt32, options::Set{Symbol})
Put the options as symbols in a set and this program will perform the option masking and call the scan start program
Note options must be a Set{Symbol}([:OPTS_DEFAULT, :OPTS_NOSCALEDATA, :OPTS_NOCALIBRATEDATA, :OPTS_EXTCLOCK, :OPTS_EXTTRIGGER, :OPTS_CONTINUOUS])

eg one value will be entered as [:OPTS_DEFAULT]
two values as [:OPTS_NOCALIBRATEDATA;:OPTS_NOSCALEDATA] etc.
"""
function mcc172_a_in_scan_start(address::Integer, channel_mask::UInt8, samples_per_channel::UInt32, options::Set{Symbol})
	# same name but keywords put in as variable args
	options_dict = Dict{Symbol, UInt32}(
	:OPTS_DEFAULT => 0x0000,         # Default behavior.
	:OPTS_NOSCALEDATA => 0x0001,     # Read / write unscaled data.
	:OPTS_NOCALIBRATEDATA => 0x0002, # Read / write uncalibrated data.
	:OPTS_EXTCLOCK => 0x0004,        # Use an external clock source.
	:OPTS_EXTTRIGGER => 0x0008,      # Use an external trigger source.
	:OPTS_CONTINUOUS => 0x0010)      # Run until explicitly stopped.

	# ensure option is valid
	options_set = Set{Symbol}([:OPTS_DEFAULT, :OPTS_NOSCALEDATA, :OPTS_NOCALIBRATEDATA,
	:OPTS_EXTCLOCK, :OPTS_EXTTRIGGER, :OPTS_CONTINUOUS])
	# @show(options, options_set)
	if !issubset(options, options_set)
		error("options must be a subset of $options_set")
	end

	optionmask = 0x0000
	for i in options
		optionmask = optionmask | options_dict[i]
	end
	mcc172_a_in_scan_start(address, channel_mask, samples_per_channel, optionmask)
end


"""
	mcc172_a_in_scan_buffer_size(address::Integer)
Returns the size of the internal scan data buffer.

An internal data buffer is allocated for the scan when 
mcc172_a_in_scan_start() is called. This function returns the total 
size of that buffer in samples.

Return:	Result code, 	RESULT_SUCCESS if successful, 
			RESULT_RESOURCE_UNAVAIL if a scan is not currently active, 
			RESULT_BAD_PARAMETER if the address is invalid or buffer_size_samples is NULL.
Parameters:
address: The board address (0 - 7). Board must already be opened.
buffer_size_samples: Receives the size of the buffer in samples. 
Each sample is a double.
"""
function mcc172_a_in_scan_buffer_size(address::Integer)
	# Returns the size of the internal scan data buffer
	# Result code, 
	# RESULT_SUCCESS if successful, 
	# RESULT_RESOURCE_UNAVAIL if a scan is not currently active, 
	# RESULT_BAD_PARAMETER if the address is invalid or buffer_size_samples is NULL.
	buffer_size_samples = Ref{UInt32}()
	resultCode = ccall((:mcc172_a_in_scan_buffer_size, "/usr/local/lib/libdaqhats.so"),
	Cint, (UInt8, Ref{UInt32}), address, buffer_size_samples)
	printError(resultCode)
	return buffer_size_samples[]
end

"""
	mcc172_a_in_scan_status(address::Integer)
Reads status and number of available samples from an analog input scan.

The scan is started with mcc172_a_in_scan_start() and runs in a 
background thread that reads the data from the board into an internal 
scan buffer. This function reads the status of the scan and amount of 
data in the scan buffer.

input Parameter:
address: The board address (0 - 7). Board must already be opened.

Return 
Result code, 	RESULT_SUCCESS if successful, 
		RESULT_RESOURCE_UNAVAIL if a scan has not been 
		started under this instance of the device.

status: Receives the scan status, an ORed combination of the flags (use mcc172_status_decode() for Array of codes):
STATUS_HW_OVERRUN: The device scan buffer was not read fast enough and data was lost.
STATUS_BUFFER_OVERRUN: The thread scan buffer was not read by the user fast enough and data was lost.
STATUS_TRIGGERED: The trigger conditions have been met.
STATUS_RUNNING: The scan is running.

samples_per_channel: Receives the number of samples per channel available in the scan thread buffer.
"""
function mcc172_a_in_scan_status(address::Integer)
	# Reads status and number of available samples from an analog input scan.
	# Status is an || combination of flags:
	# STATUS_HW_OVERRUN (0x0001) A hardware overrun occurred.
	# STATUS_BUFFER_OVERRUN (0x0002) A scan buffer overrun occurred.
	# STATUS_TRIGGERED (0x0004) The trigger event occurred.
	# STATUS_RUNNING   (0x0008) The scan is running (actively acquiring data.)

	status = Ref{UInt16}()			# Initialize
	samples_available = Ref{UInt32}()	# Initialize

	resultCode = ccall((:mcc172_a_in_scan_status, "/usr/local/lib/libdaqhats.so"),
	Cint, (UInt8, Ref{UInt16}, Ref{UInt32}), 
	address, status, samples_available)

	printError(resultCode)
	return (resultCode, status, samples_available)
end

"""
	mcc172_a_in_scan_read(address::Integer, samples_per_channel::UInt32, mcc172_num_channels::Integer, timeout::Float64)
Reads status and multiple samples from an analog input scan.

The scan is started with mcc172_a_in_scan_start() and runs in a 
background thread that reads the data from the board into an internal 
scan buffer. This function reads the data from the scan buffer, 
and returns the current scan status.

Input Parameters:
address: The board address (0 - 7). Board must already be opened.
samples_per_channel: The number of samples per channel to read. 
	Specify -1 to read all available samples in the scan thread buffer, 
	ignoring timeout. If buffer does not contain enough space then the 
	function will read as many samples per channel as will fit in buffer.
mcc172_num_channels: number of channels required to calculate buffer size
timeout: The amount of time in seconds to wait for the samples to be read. 
	Specify a negative number to wait indefinitely or 0 to return 
	immediately with whatever samples are available (up to the value of 
	samples_per_channel or buffer_size_samples.)

Return Parameters
Result code, 	RESULT_SUCCESS if successful, 
		RESULT_RESOURCE_UNAVAIL if a scan is not active.
status: Receives the scan status, an ORed combination of the flags (use mcc172_status_decode() for Array of codes):
STATUS_HW_OVERRUN: The device scan buffer was not read fast enough and data was lost.
STATUS_BUFFER_OVERRUN: The thread scan buffer was not read by the user fast enough and data was lost.
STATUS_TRIGGERED: The trigger conditions have been met.
STATUS_RUNNING: The scan is running.
buffer: The user data buffer that receives the samples.
buffer_size_samples: The size of the buffer in samples. Each sample is a double.
samples_read_per_channel: Returns the actual number of samples read from each channel.
"""
function mcc172_a_in_scan_read(address::Integer, samples_per_channel::UInt32, mcc172_num_channels::Integer, timeout::Real)
	# Reads status and number of available samples from an analog input scan.
	# Status is an || combination of flags:
	# STATUS_HW_OVERRUN (0x0001) A hardware overrun occurred.
	# STATUS_BUFFER_OVERRUN (0x0002) A scan buffer overrun occurred.
	# STATUS_TRIGGERED (0x0004) The trigger event occurred.
	# STATUS_RUNNING   (0x0008) The scan is running (actively acquiring data.)
	
	status = Ref{UInt16}()					# Initialize
	buffer_size_samples = samples_per_channel * mcc172_num_channels	# Initialize remains UInt32
	buffer = Vector{Float64}(undef, buffer_size_samples)
	samples_read_per_channel = Ref{UInt32}() # Initialize
	
	resultCode = ccall((:mcc172_a_in_scan_read, "/usr/local/lib/libdaqhats.so"),
	Cint, (UInt8, Ref{UInt16}, UInt32, Cdouble, Ptr{Cdouble}, UInt32, Ref{UInt32}), 
	address, status, samples_per_channel, timeout, buffer, buffer_size_samples, samples_read_per_channel)
	printError(resultCode)
	return resultCode, status[], buffer, Int(samples_read_per_channel[])
end

"""
	mcc172_a_in_scan_channel_count(address::Integer)
Return the number of channels in the current analog input scan.

This function returns 0 if no scan is active.

Return: The number of channels, 0 - 2.
Parameters:
address: The board address (0 - 7). Board must already be opened.
"""
function mcc172_a_in_scan_channel_count(address::Integer)
	numChannels = ccall((:mcc172_a_in_scan_channel_count, "/usr/local/lib/libdaqhats.so"),
	Cint, (UInt8,), address)
	return numChannels
end

"""
	mcc172_a_in_scan_stop(address::Integer)
Stops an analog input scan.

The scan is stopped immediately. The scan data that has been read into 
the scan buffer is available until mcc172_a_in_scan_cleanup() is called.
"""
function mcc172_a_in_scan_stop(address::Integer)
	resultCode = ccall((:mcc172_a_in_scan_stop, "/usr/local/lib/libdaqhats.so"),
	Cint, (UInt8,), address)
	printError(resultCode)
	return resultCode
end

"""
	mcc172_a_in_scan_cleanup(address::Integer)
Stops an analog input scan.

The scan is stopped immediately. The scan data that has been read into 
the scan buffer is available until mcc172_a_in_scan_cleanup() is called.
"""
function mcc172_a_in_scan_cleanup(address::Integer)
	resultCode = ccall((:mcc172_a_in_scan_cleanup, "/usr/local/lib/libdaqhats.so"),
	Cint, (UInt8,), address)
	printError(resultCode)
	return resultCode
end