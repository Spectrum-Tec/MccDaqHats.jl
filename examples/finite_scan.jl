
include(joinpath(@__DIR__, "scan_utils.jl"))

CURSOR_BACK_2 = "\x1b[2D"
ERASE_TO_END_OF_LINE = "\x1b[0K"

"""
    function finite_scan()
MCC 172 Functions Demonstrated:
    mcc172.iepe_config_write
    mcc172.a_in_clock_config_write
    mcc172.a_in_clock_config_read
    mcc172.a_in_sensitivity_write
    mcc172.a_in_scan_start
    mcc172.a_in_scan_read
    mcc172.a_in_scan_stop

Purpose:
    Perform a finite acquisition on 1 or more channels.

Description:
    Acquires blocks of analog input data for a user-specified group
    of channels.  The RMS value for each channel is displayed for each
    block of data received from the device.  The acquisition is stopped
    when the specified number of samples is acquired for each channel.

"""
function finite_scan()
    # Store the channels in a list and convert the list to a channel mask that
    # can be passed as a parameter to the MCC 172 functions.
    channels = [0, 1]
    channel_mask = chan_list_to_mask(channels)  # need to figure this one out
    num_channels = len(channels)

    sensitivity = 1000.0
    samples_per_channel = 10000
    scan_rate = 10240.0
    options = :OPS_DEFAULT

     try
        # Select an MCC 172 HAT device to use.
        address = select_hat_device(:MCC_172)   # figure out this command
        hat = mcc172(address)

        println("\nSelected MCC 172 HAT device at address $address")

        # Turn on IEPE supply?
        iepe_enable = get_iepe()

        for channel in channels
            mcc172_iepe_config_write(adress, channel, iepe_enable)
            mcc172_a_in_sensitivity_write(address, channel, sensitivity)
        end

        # Configure the clock and wait for sync to complete.
        mcc172_a_in_clock_config_write(address, :LOCAL, scan_rate)

        synced = false
        while !synced
            (_source_type, actual_scan_rate, synced) = mcc172_a_in_clock_config_read(address)
            if !synced
                sleep(0.005)
            end
        end

        println("\nMCC 172 continuous scan example")
        println("    Functions demonstrated:")
        println("         mcc172.iepe_config_write")
        println("         mcc172.a_in_clock_config_write")
        println("         mcc172.a_in_clock_config_read")
        println("         mcc172.a_in_sensitivity_write")
        println("         mcc172.a_in_scan_start")
        println("         mcc172.a_in_scan_read")
        println("         mcc172.a_in_scan_stop")
        println("         mcc172.a_in_scan_cleanup")
        println("    IEPE power: $(iepe_enable ? "on" : "off")")
        println("    Channels: $(join(chan, ", "))")
        println("    Sensitivity: $sensitivity")
        println("    Requested scan rate: $scan_rate")
        println("    Actual scan rate: $actual_scan_rate")
        println("    Samples per channel $samples_per_channel")
        println("    Options: $(enum_mask_to_string(OptionFlags, options))")

        try
            println("\nPress 'Enter' to continue")
            readline()
        catch
            error("^C to end program")
        end

        # Configure and start the scan.
        mcc172_a_in_scan_start(channel_mask, samples_per_channel, options)

        println("Starting scan ... Press Ctrl-C to stop\n")

        # Display the header row for the data table.
        println("Samples Read    Scan Count")
        for chan in channels
            println("      Ch , chan,  RMS")
        end
        println("")

        try
            read_and_display_data(adress, samples_per_channel, num_channels)

        catch # KeyboardInterrupt
            # Clear the "^C" from the display.
            println(CURSOR_BACK_2, ERASE_TO_END_OF_LINE, "\n")
            mcc172_a_in_scan_stop()
        end

        mcc172_a_in_scan_cleanup(address)

    catch # (HatError, ValueError) as err
        println("\n", err)
    end
end

"""
    function read_and_display_data(hat, samples_per_channel, num_channels)
Reads data from the specified channels on the specified DAQ HAT devices
and updates the data on the terminal display.  The reads are executed in a
loop that continues until either the scan completes or an overrun error
is detected.

Args:
hat (mcc172): The mcc172 HAT device object.
samples_per_channel: The number of samples to read for each channel.
num_channels (int): The number of channels to display.

Returns:
None

"""
function read_and_display_data(hat, samples_per_channel, num_channels)
    total_samples_read = 0
    read_request_size = 1000
    timeout = 5.0

    # Since the read_request_size is set to a specific value, a_in_scan_read()
    # will block until that many samples are available or the timeout is
    # exceeded.

    # Continuously update the display value until Ctrl-C is
    # pressed or the number of samples requested has been read.
    while total_samples_read < samples_per_channel:
        read_result = mcc172_a_in_scan_read(address, read_request_size, timeout)

        # Check for an overrun error
        if read_result.hardware_overrun:
            println("\n\nHardware overrun\n")
            break
        elif read_result.buffer_overrun:
            println("\n\nBuffer overrun\n")
            break
        end

        samples_read_per_channel = int(len(read_result.data) / num_channels)
        total_samples_read += samples_read_per_channel

        println("\r$samples_read_per_channel, $total_samples_read")

        # Display the RMS voltage for each channel.
        if samples_read_per_channel > 0
            for i in range(num_channels)
                value = calc_rms(read_result.data, i, num_channels,
                                 samples_read_per_channel)
                println("$(round(value, digits=5))")
            end
            # stdout.flush()
        end

    println("\n")
    end
end
