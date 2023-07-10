using Revise
using MccDaqHats
using Infiltrator
includet(joinpath(@__DIR__, "scan_utils.jl"))

#Constants
const READ_ALL_AVAILABLE = -1
const CURSOR_BACK_2 = "\x1b[2D"
const ERASE_TO_END_OF_LINE = "\x1b[0K"

"""
    function continuous_scan()
Example for continuous scan
MCC 172 Functions Demonstrated:
    mcc172_iepe_config_write
    mcc172_a_in_clock_config_write
    mcc172_a_in_clock_config_read
    mcc172_a_in_scan_start
    mcc172_a_in_scan_read
    mcc172_a_in_scan_stop
    mcc172_a_in_scan_cleanup

Purpose:
    Performa a continuous acquisition on 1 or more channels.

Description:
    Continuously acquires blocks of analog input data for a
    user-specified group of channels until the acquisition is
    stopped by the user.  The RMS voltage for each channel
    is displayed for each block of data received from the device.
"""
function continuous_scan()

    # Store the channels in a list and convert the list to a channel mask that
    # can be passed as a parameter to the MCC 172 functions.
    channels = [0, 1]
    num_channels = length(channels)

    samples_per_channel = 0

    options = [OPTS_CONTINUOUS]

    scan_rate = 10240.0

    try
        # Select an MCC 172 HAT device to use.
        hat = select_hat_devices(:MCC_172, 1)
        address = hat[1].address

        println("\nSelected MCC 172 HAT device at address $address")

        # Turn on IEPE supply?
        iepe_enable = get_iepe()

        mcc172_open(address)
        for channel in channels
            mcc172_iepe_config_write(address, channel, iepe_enable)
            # mcc172_a_in_sensitivity_write(address, channel, sensitivity)
        end
     
        # Configure the clock and wait for sync to complete.
        mcc172_a_in_clock_config_write(address, SOURCE_LOCAL, scan_rate)

        synced = false
        actual_scan_rate = 0.0  # initialize to Float64
        while !synced
            (_source_type, actual_scan_rate, synced) = mcc172_a_in_clock_config_read(address)
            if !synced
                sleep(0.005)
            end
        end

        println("\nMCC 172 continuous scan example")
        println("    Functions demonstrated:")
        println("         mcc172_iepe_config_write")
        println("         mcc172_a_in_clock_config_write")
        println("         mcc172_a_in_clock_config_read")
        println("         mcc172_a_in_scan_start")
        println("         mcc172_a_in_scan_read")
        println("         mcc172_a_in_scan_stop")
        println("         mcc172_a_in_scan_cleanup")
        println("    IEPE power: $(iepe_enable ? "on" : "off")")
        println("    Channels: $(join(channels, ", "))")
        println("    Requested scan rate: $scan_rate")
        println("    Actual scan rate: $(round(actual_scan_rate, digits=3))")
        println("    Samples per channel $(round(samples_per_channel, digits=3))")
        println("    Options: $(options)")

        try
            println("\nPress 'Enter' to continue")
            readline()
        catch
            error("^C to end program")
        end


        # Configure and start the scan.
        # Since the continuous option is being used, the samples_per_channel
        # parameter is ignored if the value is less than the default internal
        # buffer size (10000 * num_channels in this case). If a larger internal
        # buffer size is desired, set the value of this parameter accordingly.
        # Configure and start the scan.
        channel_mask = chan_list_to_mask(channels)
        mcc172_a_in_scan_start(address, channel_mask, samples_per_channel, options)
  
        # Display the header row for the data table.
        println("Samples Read    Scan Count")
        for (chan, item) in enumerate(channels)
            print("       Channel $item")
        end
        println()

        try
            read_and_display_data(address, samples_per_channel, num_channels)
            
        catch e # KeyboardInterrupt
            if isa(e, InterruptException)
                # Clear the "^C" from the display.
                println("$CURSOR_BACK_2, $ERASE_TO_END_OF_LINE, Aborted\n")
            else
                println("\n $e")
            end
            mcc172_a_in_scan_stop(address)
        end
        
        mcc172_a_in_scan_cleanup(address)
        
        # Turn off IEPE supply
        for channel in chans[i]
            mcc172_iepe_config_write(hat.address, channel, false)
        end
    catch err  # (HatError, ValueError) as err
        println("\n $err")
    end
    return nothing
end

"""
    function read_and_display_data(address, samples_per_channel, num_channels):
Reads data from the specified channels on the specified DAQ HAT devices
and updates the data on the terminal display.  The reads are executed in a
loop that continues until the user stops the scan or an overrun error is
detected.

Args:
hat (mcc172): The mcc172 HAT device object.
num_channels (int): The number of channels to display.

Returns:
Nothing
"""
function read_and_display_data(address::Integer, samples_per_channel::Integer, num_channels::Integer)
    total_samples_read = 0
    read_request_size = READ_ALL_AVAILABLE
    
    # When doing a continuous scan, the timeout value will be ignored in the
    # call to a_in_scan_read because we will be requesting that all available
    # samples (up to the default buffer size) be returned.
    timeout = 5.0
    
    # Read all of the available samples (up to the size of the read_buffer which
    # is specified by the user_buffer_size).  Since the read_request_size is set
    # to -1 (READ_ALL_AVAILABLE), this function returns immediately with
    # whatever samples are available (up to user_buffer_size) and the timeout
    # parameter is ignored.
    while true
        #sleep(0.001)
        #read_request_size = 10000
        #@show(address, read_request_size, num_channels, timeout)
        #println("Here I Am before")
        # @infiltrate
        resultcode, statuscode, result, samples_read = 
        mcc172_a_in_scan_read(address, Int32(read_request_size), num_channels, timeout)
        #print("Here I Am after")
        
        # Check for an overrun error
        status = mcc172_status_decode(statuscode)
        if status.hardwareoverrun
            println("\n\nHardware overrun\n")
            break
        elseif status.bufferoverrun
            println("\n\nBuffer overrun\n")
            break
        end
        
        samples_read_per_channel = length(result) ÷ num_channels
        total_samples_read += samples_read_per_channel
        
        print("\r$samples_read_per_channel   $total_samples_read")
        
        # Display the RMS voltage for each channel.
        if samples_read_per_channel > 0
            for i in 1:num_channels
                #@show(length(result), i, num_channels, samples_read_per_channel)
                value = calc_rms(result, i, num_channels, samples_read_per_channel)
                print(" chan $i $(round(value, digits=5)) Vrms ")
            end
            #stdout.flush()
            
            sleep(0.1)
        end
        
        println("\n")
    end
end