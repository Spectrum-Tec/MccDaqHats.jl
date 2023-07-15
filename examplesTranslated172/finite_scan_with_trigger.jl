# started conversion from Python to julia
using Revise
using MccDaqHats
#using Infiltrator
includet(joinpath(@__DIR__, "scan_utils.jl"))

# Constants
CURSOR_BACK_2 = "\x1b[2D"
ERASE_TO_END_OF_LINE = "\x1b[0K"

"""
MCC 172 Functions Demonstrated:
    mcc172_trigger_config
    mcc172_iepe_config_write
    mcc172_a_in_clock_config_write
    mcc172_a_in_clock_config_read
    mcc172_a_in_scan_start
    mcc172_a_in_scan_read
    mcc172_a_in_scan_stop

Purpose:    
    Perform a triggered finite acquisition on 1 or more channels.

Description:    
    Waits for an external trigger to occur and then acquires blocks
    of analog input data for a user-specified group of channels.  The
    RMS voltage for each channel is displayed for each block
    of data received from the device.  The acquisition is stopped when    
    the specified number of samples is acquired for each channel.
"""            
function finite_scan_with_trigger()
    # Store the channels in a list and convert the list to a channel mask that
    # can be passed as a parameter to the MCC 172 functions.
    channels = [0, 1]
    channel_mask = chan_list_to_mask(channels)
    num_channels = length(channels)

    samples_per_channel = UInt32(10000)
    scan_rate = 10240.0
    options = [OPTS_EXTTRIGGER]
    trigger_mode = TRIG_RISING_EDGE

    try
        # Select an MCC 172 HAT device to use.
        hats = select_hat_devices(HAT_ID_MCC_172, 1)
        address = hats[1].address

        print("\nSelected MCC 172 HAT device at address $address")

        # Turn on IEPE supply?
        iepe_enable = get_iepe()
        
        mcc172_open(address)
        for channel in channels
            mcc172_iepe_config_write(address, channel, iepe_enable)
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
        println("         mcc172_trigger_mode")
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
        println("    Samples per channel $samples_per_channel")
        println("    Options: $(options)")
        println("    Trigger Mode: $trigger_mode")

        try
            println("\nPress 'Enter' to continue")
            readline()
        catch
            error("^C to end program")
        end

        mcc172_trigger_config(address, SOURCE_LOCAL, trigger_mode)

        # Configure and start the scan.
        mcc172_a_in_scan_start(address, channel_mask, samples_per_channel, options)

        try
            # wait for the external trigger to occur
            println("\nWaiting for trigger ... hit Ctrl-C to cancel the trigger")
            wait_for_trigger(address)
            
            println("\nStarting scan ... Press Ctrl-C to stop\n")
            
            # Display the header row for the data table.
            print("Samples Read    Scan Count")
            for chan in channels
                print("       Channel  $chan")
            end
            println()
            
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
        
    catch err  # (HatError, ValueError) as err
        println("\n $err")
    end
end

"""
Reads data from the specified channels on the specified DAQ HAT devices
and updates the data on the terminal display.  The reads are executed in a
loop that continues until either the scan completes or an overrun error
is detected.

Args:
hat (mcc172): The mcc172 HAT device object.
samples_per_channel: The number of samples to read for each channel.
num_channels (int): The number of channels to display.

Returns:
Nothing
"""
function read_and_display_data(address::Integer, samples_per_channel::Integer, num_channels::Integer)
    total_samples_read = 0
    read_request_size = 1000
    timeout = 5.0
    
    # Since the read_request_size is set to a specific value, a_in_scan_read()
    # will block until that many samples are available or the timeout is
    # exceeded.
    
    # Continuously update the display value until Ctrl-C is pressed
    # or the number of samples requested has been read.
    while total_samples_read < samples_per_channel
        resultcode, statuscode, result, samples_read = 
        mcc172_a_in_scan_read(address, Int32(read_request_size), num_channels, timeout)
        # @show(length(result), samples_read)

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

        print("\r$(samples_read_per_channel)         $(total_samples_read)")

        # Display the RMS voltage for each channel.
        if samples_read_per_channel > 0
            for i in 1:num_channels
                value = calc_rms(result, i, num_channels, samples_read_per_channel)
                print("      $(round(value, digits=5)) Vrms   ")
            end
            println()
        end
    end
    print("\n")
end