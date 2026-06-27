# module Mcc128

using CEnum

@cenum AnalogInputMode::UInt32 begin
    A_IN_MODE_SE = 0
    A_IN_MODE_DIFF = 1
end

@cenum AnalogInputRange::UInt32 begin
    A_IN_RANGE_BIP_10V = 0
    A_IN_RANGE_BIP_5V = 1
    A_IN_RANGE_BIP_2V = 2
    A_IN_RANGE_BIP_1V = 3
end

struct MCC128DeviceInfo
    NUM_AI_MODES::UInt8
    NUM_AI_CHANNELS::NTuple{2, UInt8}
    AI_MIN_CODE::UInt16
    AI_MAX_CODE::UInt16
    NUM_AI_RANGES::UInt8
    AI_MIN_VOLTAGE::NTuple{4, Cdouble}
    AI_MAX_VOLTAGE::NTuple{4, Cdouble}
    AI_MIN_RANGE::NTuple{4, Cdouble}
    AI_MAX_RANGE::NTuple{4, Cdouble}
end

"""
	mcc128_open(address::Integer)
Open a connection to the MCC 128 device at the specified address.

Parameters:
address: board address (0-7)

Returns: 
Result code, RESULT_SUCCESS if successful.
"""
function mcc128_open(address)
    resultcode = ccall((:mcc128_open, libdaqhats), Cint, (UInt8,), address)
	printError(resultcode)
	return resultcode
end

"""
	mcc128_is_open(address::Integer)
Check if an MCC 128 is open.

Parameters:
address: board address (0-7)

Returns:
 `true' if open, 'false' if not open.
"""
function mcc128_is_open(address)
    resultcode = ccall((:mcc128_is_open, libdaqhats), Cint, (UInt8,), address)
    printError(resultcode)
	return resultcode
end

"""
	mcc128_close(address::Integer)
Close a connection to an MCC 128 device and free allocated resources.

Parameters:
address: board address (0-7)

Returns: 
Result code, RESULT_SUCCESS if successful.
"""
function mcc128_close(address)
    resultcode = ccall((:mcc128_close, libdaqhats), Cint, (UInt8,), address)
    printError(resultcode)
	return resultcode
end

"""
	mcc128_info()
Return device information for all MCC 128s.

Returns: struct MCC128DeviceInfo.
"""
function mcc128_info()
    output_ptr = ccall((:mcc128_info, libdaqhats), Ptr{MCC128DeviceInfo}, ())
    mcc128_device_info = unsafe_load(Ptr{MCC128DeviceInfo}(output_ptr))
	return mcc128_device_info
end

"""
	mcc128_blink_led(address::Integer, count::Integer)
Blink the LED on the MCC 128.

Passing 0 for count will result in the LED blinking continuously until 
the board is reset or `mcc128_blink_led()` is called again with a non-zero 
value for count.

Parameters:
address: The board address (0-7)
count: The number of times to blink (0 - 255)

Returns:  
Result code, RESULT_SUCCESS if successful.
"""
function mcc128_blink_led(address, count)
    resultcode = ccall((:mcc128_blink_led, libdaqhats), Cint, (UInt8, UInt8), address, count)
    printError(resultcode)
	return resultcode
end

"""
	mcc128_firmware_version(address::Integer)
Return the board firmware version.

address – The board address (0 - 7). Board must already be opened.

Returns:
Result code, RESULT_SUCCESS if successful.
version – Receives the firmware version. The version will be in BCD hexadecimal with the high byte as the major 
        version and low byte as minor, i.e. 0x0103 is version 1.03.
"""
function mcc128_firmware_version(address, version)
    # Note difference from mcc172_firmware_version
    resultcode = ccall((:mcc128_firmware_version, libdaqhats), Cint, (UInt8, Ptr{UInt16}), address, version)
    printError(resultcode)
	return (resultcode, version[])
end

"""
	mcc128_serial(address::Integer)
Read the MCC 128 serial number.

Parameters:
address – The board address (0 - 7). Board must already be opened.

Returns:
Result code, RESULT_SUCCESS if successful.
"""
function mcc128_serial(address, buffer)
    buffer = Vector{UInt8}(undef, 9)  # initialize serial buffer
	resultcode = ccall((:mcc128_serial, libdaqhats), Cint, (UInt8, Ptr{Cchar}), address, buffer)
    printError(resultcode)
	return (result_code, unsafe_string(pointer(buffer)))
end

"""
	mcc128_calibration_date(address::Integer)
Read the MCC 128 calibration date.

Parameters:
address – The board address (0 - 7). Board must already be opened.

Returns:
Result code, RESULT_SUCCESS if successful.
Date - is a string (format “YYYY-MM-DD”)
"""
function mcc128_calibration_date(address, buffer)
    buffer = Vector{UInt8}(undef,11) # initialized string
	resultcode = ccall((:mcc128_calibration_date, libdaqhats), Cint, (UInt8, Ptr{Cchar}), address, buffer)
    printError(resultcode)
	# return calDate
	buffer[end] = 0
	return (resultcode, unsafe_string(pointer(caldate)))
end

"""
	mcc128_calibration_coefficient_read(address::Integer, channel::Integer)
Read the MCC 128 calibration coefficients for a specified input range.

The coefficients are applied in the library as:
`calibrated_ADC_code = (raw_ADC_code * slope) + offset`

Parameters:
address – The board address (0 - 7). Board must already be opened.
range – The input range, one of the input range values.

Returns:
slope – Receives the slope.
offset – Receives the offset.
Result code, RESULT_SUCCESS if successful.
"""
function mcc128_calibration_coefficient_read(address, range, slope, offset)
    # slightly different from mcc172_calibration_coefficient_read
    slope = offset = Ref{Cdouble}()
    resultcode = ccall((:mcc128_calibration_coefficient_read, libdaqhats), 
        Cint, (UInt8, UInt8, Ptr{Cdouble}, Ptr{Cdouble}), address, range, slope, offset)
    printError(resultcode)
	return (resultcode, slope[], offset[])
end

"""
	mcc128_calibration_coefficient_write(address::Integer, channel::Integer, slope::AbstractFloat, offset::AbstractFloat)
Temporarily write the MCC 128 calibration coefficients for a specified input range.

The user can apply their own calibration coefficients by writing to these values. The 
values will reset to the factory values from the EEPROM whenever mcc128_open() is called. 
This function will fail and return RESULT_BUSY if a scan is active when it is called.

The coefficients are applied in the library as:
`calibrated_ADC_code = (raw_ADC_code * slope) + offset`

Parameters:
address – The board address (0 - 7). Board must already be opened.
range – The input range, one of the input range values.
slope – The new slope value.
offset – The new offset value.

Returns:  
Result code, RESULT_SUCCESS if successful.
"""
function mcc128_calibration_coefficient_write(address, range, slope, offset)
    resultcode = ccall((:mcc128_calibration_coefficient_write, libdaqhats), Cint, (UInt8, UInt8, Cdouble, Cdouble), address, range, slope, offset)
    printError(resultcode)
	return resultcode
end

"""
    mcc128_a_in_mode_write(address, mode)
Reads the current analog input mode.

Parameters:
address – The board address (0 - 7). Board must already be opened.
mode – Receives the input mode.

Returns: 
Result code, RESULT_SUCCESS if successful.
"""
function mcc128_a_in_mode_read(address)
    mode = Ref{UInt8}
    resultcode = ccall((:mcc128_a_in_mode_read, libdaqhats), Cint, (UInt8, Ptr{UInt8}), address, mode)
    printError(resultcode)
	return unsafe_convert(mode)
end

"""
    mcc128_a_in_mode_write(address, mode)
Set the analog input mode.

This sets the analog inputs to one of the valid values:
A_IN_MODE_SE: Single-ended (8 inputs relative to ground.)
A_IN_MODE_DIFF: Differential (4 channels with positive and negative inputs.)

This function will fail and return RESULT_BUSY if a scan is active when it is called.

Parameters:
address – The board address (0 - 7). Board must already be opened.
mode – One of the input mode values.

Returns:  
Result code, RESULT_SUCCESS if successful.
"""
function mcc128_a_in_mode_write(address, mode)
    resultcode = ccall((:mcc128_a_in_mode_write, libdaqhats), Cint, (UInt8, UInt8), address, mode)
    printError(resultcode)
	return resultcode
end

"""
    mcc128_a_in_range_write(address, range)
Set the analog input range.

This sets the analog input range to one of the valid ranges:
    A_IN_RANGE_BIP_10V: +/- 10V
    A_IN_RANGE_BIP_5V: +/- 5V
    A_IN_RANGE_BIP_2V: +/- 2V
    A_IN_RANGE_BIP_1V: +/- 1V

This function will fail and return RESULT_BUSY if a scan is active when it is called.

Parameters:
address – The board address (0 - 7). Board must already be opened.
range – One of the input range values.

Returns: 
Result code, RESULT_SUCCESS if successful.
"""
function mcc128_a_in_range_write(address, range)
    resultcode = ccall((:mcc128_a_in_range_write, libdaqhats), Cint, (UInt8, UInt8), address, range)
    printError(resultcode)
	return resultcode
end

"""
    mcc128_a_in_range_read(address)
Read the analog input range.

Returns the current analog input range.

Parameters:
address – The board address (0 - 7). Board must already be opened.

Returns:  
Result code, RESULT_SUCCESS if successful.
range – Receives the input range.
"""
function mcc128_a_in_range_read(address)
    range = Ref{UInt8}()
    resultcode = ccall((:mcc128_a_in_range_read, libdaqhats), Cint, (UInt8, Ptr{UInt8}), address, range)
    printError(resultcode)
	return (resultcode, range)
end

"""
Perform a single reading of an analog input channel and return the value.

The valid options are:
OPTS_NOSCALEDATA: Return ADC code (a value between 0 and 65535) rather than voltage.
OPTS_NOCALIBRATEDATA: Return data without the calibration factors applied.

The options parameter is set to 0 or OPTS_DEFAULT for default operation, which is scaled and 
calibrated data.  Multiple options may be specified by ORing the flags. For instance, 
specifying OPTS_NOSCALEDATA | OPTS_NOCALIBRATEDATA will return the value read from the 
ADC without calibration or converting to voltage.

The function will return RESULT_BUSY if called while a scan is running.

Parameters:
address – The board address (0 - 7). Board must already be opened.
channel – The analog input channel number, 0 - 7.
options – Options bitmask.

Returns:
Result code, RESULT_SUCCESS if successful.
value – Receives the analog input value.
"""
function mcc128_a_in_read(address, channel; options=OPTS_DEFAULT)
    value = Ref{UInt8}()
    resultcode = ccall((:mcc128_a_in_read, libdaqhats), Cint, (UInt8, UInt8, UInt32, Ptr{Cdouble}), address, channel, options, value)
    printError(resultcode)
	return (resultcode, value)
end

"""
mcc128_trigger_mode(address, mode)
Set the trigger input mode.

Parameters:
address – The board address (0 - 7). Board must already be opened.
mode – One of the trigger mode values.

Returns: 
Result code, RESULT_SUCCESS if successful.
"""
function mcc128_trigger_mode(address, mode)
    resultcode = ccall((:mcc128_trigger_mode, libdaqhats), Cint, (UInt8, UInt8), address, mode)
    printError(resultcode)
	return resultcode
end

"""
Read the actual sample rate per channel for a requested sample rate.

The internal scan clock is generated from a 16 MHz clock source so only discrete frequency steps can be achieved. This function will return the actual rate for a requested channel count and rate. This function does not perform any actions with a board, it simply calculates the rate.

Parameters:
channel_count – The number of channels in the scan.
sample_rate_per_channel – The desired sampling rate in samples per second per channel, max 100,000.

Returns:
Result code, RESULT_SUCCESS if successful, RESULT_BAD_PARAMETER if the scan parameters are not achievable on an MCC 128.
actual_sample_rate_per_channel – The actual sample rate that would occur when requesting this rate on an MCC 128, or 0 if there is an error.
"""
function mcc128_a_in_scan_actual_rate(channel_count, sample_rate_per_channel)
    actual_sample_rate_per_channel = Ref{Float64}()
    resultcode = ccall((:mcc128_a_in_scan_actual_rate, libdaqhats), Cint, (UInt8, Cdouble, Ptr{Cdouble}), channel_count, sample_rate_per_channel, actual_sample_rate_per_channel)
    printError(resultcode)
	return (resultcode, unsafe_convert(actual_sample_rate_per_channel))
end

# created by Clang but not in documentation
function mcc128_a_in_scan_queue_start(address, queue_count, queue, samples_per_channel, sample_rate_per_channel, options)
    resultcode = ccall((:mcc128_a_in_scan_queue_start, libdaqhats), Cint, (UInt8, UInt8, Ptr{UInt8}, UInt32, Cdouble, UInt32), address, queue_count, queue, samples_per_channel, sample_rate_per_channel, options)
    printError(resultcode)
	return (resultcode, unsafe_load(queue))
end

"""
    mcc128_a_in_scan_start(address, channel_mask, samples_per_channel, sample_rate_per_channel, options)
Start a hardware-paced analog input scan.

The scan runs as a separate thread from the user’s code. The function will allocate a 
scan buffer and read data from the device into that buffer. The user reads the data 
from this buffer and the scan status using the mcc128_a_in_scan_read() function. 
mcc128_a_in_scan_stop() is used to stop a continuous scan, or to stop a finite scan
before it completes. The user must call mcc128_a_in_scan_cleanup() after the scan 
has finished and all desired data has been read; this frees all resources from the 
scan and allows additional scans to be performed.

The scan state has defined terminology:
Active: mcc128_a_in_scan_start() has been called and the device may be acquiring 
    data or finished with the acquisition. The scan has not been cleaned up by calling 
    mcc128_a_in_scan_cleanup(), so another scan may not be started.
Running: The scan is active and the device is still acquiring data. Certain 
functions like mcc128_a_in_read() will return an error because the device is busy.

The valid options are:
OPTS_NOSCALEDATA: Returns ADC code (a value between 0 and 65535) rather than voltage.
OPTS_NOCALIBRATEDATA: Return data without the calibration factors applied.
OPTS_EXTCLOCK: Use an external 3.3V or 5V logic signal at the CLK input as the scan clock. 
    Multiple devices can be synchronized by connecting the CLK pins together and using this 
    option on all but one device so they will be clocked by the single device using its 
    internal clock. sample_rate_per_channel is only used for buffer sizing.
OPTS_EXTTRIGGER: Hold off the scan (after calling mcc128_a_in_scan_start()) until 
    the trigger condition is met. The trigger is a 3.3V or 5V logic signal applied to 
    the TRIG pin.
OPTS_CONTINUOUS: Scans continuously until stopped by the user by calling 
    mcc128_a_in_scan_stop() and writes data to a circular buffer. The data must be read 
    before being overwritten to avoid a buffer overrun error. samples_per_channel 
    is only used for buffer sizing.

The options parameter is set to 0 or OPTS_DEFAULT for default operation, which 
is scaled and calibrated data, internal scan clock, no trigger, and finite operation.

Multiple options may be specified by ORing the flags. For instance, specifying 
OPTS_NOSCALEDATA | OPTS_NOCALIBRATEDATA will return the values read from the ADC 
without calibration or converting to voltage.

The buffer size will be allocated as follows:
Finite mode: Total number of samples in the scan
Continuous mode (buffer size is per channel): Either samples_per_channel or the 
    value in the following table, whichever is greater

Sample Rate     Buffer Size (per channel)
Not specified   10 kS
0-100 S/s       1 kS
100-10k S/s     10 kS
10k-100k S/s    100 kS

Specifying a very large value for samples_per_channel could use too much of the 
    Raspberry Pi memory. If the memory allocation fails, the function will return 
    RESULT_RESOURCE_UNAVAIL. The allocation could succeed, but the lack of free 
    memory could cause other problems in the Raspberry Pi. If you need to acquire 
    a high number of samples then it is better to run the scan in continuous mode 
    and stop it when you have acquired the desired amount of data. If a scan is 
    already active this function will return RESULT_BUSY.

Parameters:
address – The board address (0 - 7). Board must already be opened.
channel_mask – A bit mask of the channels to be scanned. Set each bit to enable 
    the associated channel (0x01 - 0xFF.)
samples_per_channel – The number of samples to acquire for each channel in the 
    scan (finite mode), or can be used to set a larger scan buffer size than the 
    default value (continuous mode.)
sample_rate_per_channel – The sampling rate in samples per second per channel, 
    max 100,000. When using an external sample clock set this value to the maximum 
    expected rate of the clock.
options – The options bitmask.

Returns: 
Result code, RESULT_SUCCESS if successful, RESULT_BUSY if a scan is already active.
"""
function mcc128_a_in_scan_start(address, channel_mask, samples_per_channel, sample_rate_per_channel, options)
    resultcode = ccall((:mcc128_a_in_scan_start, libdaqhats), Cint, (UInt8, UInt8, UInt32, Cdouble, UInt32), address, channel_mask, samples_per_channel, sample_rate_per_channel, options)
    printError(resultcode)
	return resultcode
end

"""
    mcc128_a_in_scan_buffer_size(address)
Returns the size of the internal scan data buffer.

An internal data buffer is allocated for the scan when mcc128_a_in_scan_start() 
is called. This function returns the total size of that buffer in samples.

Parameters:
address – The board address (0 - 7). Board must already be opened.

Returns: 
Result Code
    RESULT_SUCCESS if successful, 
    RESULT_RESOURCE_UNAVAIL if a scan is not currently active, 
    RESULT_BAD_PARAMETER if the address is invalid or buffer_size_samples is NULL.
buffer_size_samples – Receives the size of the buffer in samples. Each sample is a double.
"""
function mcc128_a_in_scan_buffer_size(address, buffer_size_samples)
    resultcode = ccall((:mcc128_a_in_scan_buffer_size, libdaqhats), Cint, (UInt8, Ptr{UInt32}), address, buffer_size_samples)
    printError(resultcode)
	return (resultcode, buffer_size_samples)
end

"""
    mcc128_a_in_scan_status(address, status, samples_per_channel)
Reads status and number of available samples from an analog input scan.

The scan is started with mcc128_a_in_scan_start() and runs in a background thread 
that reads the data from the board into an internal scan buffer. This function 
reads the status of the scan and amount of data in the scan buffer.

Parameters:
address – The board address (0 - 7). Board must already be opened.

Returns:
Result code, 
    RESULT_SUCCESS if successful, 
    RESULT_RESOURCE_UNAVAIL if a scan has not been started under this instance of the device.
status – Receives the scan status, an ORed combination of the flags:
    STATUS_HW_OVERRUN: The device scan buffer was not read fast enough and data was lost.
    STATUS_BUFFER_OVERRUN: The thread scan buffer was not read by the user fast enough and data was lost.
    STATUS_TRIGGERED: The trigger conditions have been met.
    STATUS_RUNNING: The scan is running.
samples_per_channel – Receives the number of samples per channel available in the scan thread buffer.
"""
function mcc128_a_in_scan_status(address)
    status = Ref{UInt16}()
    samples_per_channel = Ref{UInt32}()
    resultcode = ccall((:mcc128_a_in_scan_status, libdaqhats), Cint, (UInt8, Ptr{UInt16}, Ptr{UInt32}), address, status, samples_per_channel)
    printError(resultcode)
	return (resultcode, unsafe_convert(status), unsafe_convert(samples_per_channel))
end

"""
    mcc128_a_in_scan_read(address, status, samples_per_channel, timeout, buffer, buffer_size_samples, samples_read_per_channel)
Reads status and multiple samples from an analog input scan.

The scan is started with mcc128_a_in_scan_start() and runs in a background thread that reads 
the data from the board into an internal scan buffer. This function reads the data from the 
scan buffer, and returns the current scan status.

Parameters:
address – The board address (0 - 7). Board must already be opened.
samples_per_channel – The number of samples per channel to read. Specify -1 to read all 
    available samples in the scan thread buffer, ignoring timeout. If buffer does not contain 
    enough space then the function will read as many samples per channel as will fit in buffer.
timeout – The amount of time in seconds to wait for the samples to be read. Specify a negative number to wait indefinitely or 0 to return immediately with whatever samples are available (up to the value of samples_per_channel or buffer_size_samples.)
buffer_size_samples – The size of the buffer in samples. Each sample is a double.
    
Returns:
Result code, RESULT_SUCCESS if successful, RESULT_RESOURCE_UNAVAIL if a scan is not active.
status – Receives the scan status, an ORed combination of the flags:
    STATUS_HW_OVERRUN: The device scan buffer was not read fast enough and data was lost.
    STATUS_BUFFER_OVERRUN: The thread scan buffer was not read by the user fast enough and data was lost.
    STATUS_TRIGGERED: The trigger conditions have been met.
    STATUS_RUNNING: The scan is running.
buffer – The user data buffer that receives the samples.
samples_read_per_channel – Returns the actual number of samples read from each channel.
"""
function mcc128_a_in_scan_read(address, samples_per_channel, timeout, buffer_size_samples)
    resultcode = ccall((:mcc128_a_in_scan_read, libdaqhats), 
        Cint, (UInt8, Ptr{UInt16}, Int32, Cdouble, Ptr{Cdouble}, UInt32, Ptr{UInt32}), 
        address, status, samples_per_channel, timeout, buffer, buffer_size_samples, samples_read_per_channel)
    printError(resultcode)
	return (resultcode, status, buffer, samples_read_per_channel)
end

# function mcc128_a_in_scan_read!()

"""
    mcc128_a_in_scan_stop(address)
Stops an analog input scan.

The scan is stopped immediately. The scan data that has been read into the scan buffer 
is available until mcc128_a_in_scan_cleanup() is called.

Parameters:
address – The board address (0 - 7). Board must already be opened.

Returns: 
Result code, RESULT_SUCCESS if successful.
"""
function mcc128_a_in_scan_stop(address)
    resultcode = ccall((:mcc128_a_in_scan_stop, libdaqhats), Cint, (UInt8,), address)
    printError(resultcode)
	return resultcode
end

"""
    mcc128_a_in_scan_cleanup(address)
Free analog input scan resources after the scan is complete.

Parameters:
address – The board address (0 - 7). Board must already be opened.

Returns: 
Result code, RESULT_SUCCESS if successful.
"""
function mcc128_a_in_scan_cleanup(address)
    resultcode = ccall((:mcc128_a_in_scan_cleanup, libdaqhats), Cint, (UInt8,), address)
    printError(resultcode)
	return resultcode
end

"""
mcc128_a_in_scan_channel_count(address)
Free analog input scan resources after the scan is complete.

Parameters:
address – The board address (0 - 7). Board must already be opened.

Returns:
Result code, RESULT_SUCCESS if successful.
"""
function mcc128_a_in_scan_channel_count(address)
    resultcode = ccall((:mcc128_a_in_scan_channel_count, libdaqhats), Cint, (UInt8,), address)
    printError(resultcode)
	return resultcode
end

# The following two functions were created by Clang but are not in the documentation
function mcc128_test_clock(address, mode, value)
    resultcode = ccall((:mcc128_test_clock, libdaqhats), Cint, (UInt8, UInt8, Ptr{UInt8}), address, mode, value)
    printError(resultcode)
	return resultcode
end

function mcc128_test_trigger(address, state)
    resultcode = ccall((:mcc128_test_trigger, libdaqhats), Cint, (UInt8, Ptr{UInt8}), address, state)
    printError(resultcode)
	return resultcode
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

#=
# exports
const PREFIXES = ["mcc128"]
for name in names(@__MODULE__; all=true), prefix in PREFIXES
    if startswith(string(name), prefix)
        @eval export $name
    end
end
end # module
=#
