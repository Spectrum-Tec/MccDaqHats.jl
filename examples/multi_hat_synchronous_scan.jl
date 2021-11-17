using MccDaqHats
using Revise
include(joinpath(@__DIR__, "scan_utils.jl"))

# Constants
const DEVICE_COUNT = 2
const MASTER = 0
const CURSOR_SAVE = "\x1b[s"
const CURSOR_RESTORE = "\x1b[u"
const CURSOR_BACK_2 = "\x1b[2D"
const ERASE_TO_END_OF_LINE = "\x1b[0K"


"""
multi_hat_synchronous_scan()
        MCC 172 Functions Demonstrated:
        mcc172_trigger_config
        mcc172_a_in_clock_config_write
        mcc172_a_in_clock_config_read
        mcc172_a_in_scan_start
        mcc172_a_in_scan_status
        mcc172_a_in_scan_read
        mcc172_a_in_scan_stop

    Purpose:
        Get synchronous data from multiple MCC 172 devices.

    Description:
        This example demonstrates acquiring data synchronously from multiple
        MCC 172 devices.  This is done using the shared clock and trigger
        options.  An external trigger source must be provided to the TRIG
        terminal on the master MCC 172 device.  The clock and trigger on the
        master device are configured for SOURCE_MASTER and the remaining devices
        are configured for SOURCE_SLAVE.

"""
function multi_hat_synchronous_scan()
    # hats = []

    # Define the channel list for each HAT device
    chans = [[0 1]; [0 1]]
    
    # Define the options for each HAT device
    options = [:OPTS_EXTTRIGGER; :OPTS_EXTTRIGGER]
    samples_per_channel = 10000
    sample_rate = 10240.0  # Samples per second
    trigger_mode = :TRIG_RISING_EDGE

    try
        # Get an instance of the selected hat device object.
        hats = select_hat_devices(:MCC_172, DEVICE_COUNT)

        # Validate the selected channels.
        for (i, hat) in enumerate(hats)
            validate_channels(chans[i], hat.info.NUM_AI_CHANNELS)
        end 

        # Turn on IEPE supply?
        iepe_enable = get_iepe()

        for (i, hat) in enumerate(hats)
            for channel in chans[i]
                # Configure IEPE.
                mcc172_iepe_config_write(channel, iepe_enable)
            end
            if hat.address != MASTER
                # Configure the slave clocks.
                mcc172_a_in_clock_config_write(hat.address, :SOURCE_SLAVE, sample_rate)
                # Configure the trigger.
                mcc172_trigger_config(hat.address, :SOURCE_SLAVE, trigger_mode)
            end
        end

        # Configure the master clock and start the sync.
        mcc172_a_in_clock_config_write(MASTER, :SOURCE_MASTER, sample_rate)
        synced = false
        while !synced
            _source_type, actual_rate, synced = mcc172_a_in_clock_config_read(MASTER)
            if !synced
                sleep(0.005)
            end
        end

        # Configure the master trigger.
        mcc172_trigger_config(MASTER, :SOURCE_MASTER, trigger_mode)

        println("MCC 172 multiple HAT example using external clock and external trigger options")
        println("    Functions demonstrated:")
        println("         mcc172.trigger_mode")
        println("         mcc172.a_in_clock_config_write")
        println("         mcc172.a_in_clock_config_read")
        println("         mcc172.a_in_scan_start")
        println("         mcc172.a_in_scan_read")
        println("         mcc172.a_in_scan_stop")
        println("         mcc172.a_in_scan_cleanup")
        println("    IEPE power: $(iepe_enable ? "on" : "off")")
        println("    Samples per channel:", samples_per_channel)
        println("    Requested Sample Rate: $(round(sample_rate, digits=3))")
        println("    Actual Sample Rate: $(round(actual_rate, digits=3))")
        println("    Trigger type: $trigger_mode")

        for (i, hat) in enumerate(hats)
            println("    HAT: $i")
            println("      Address: $(hat.address)")
            println("      Channels: $(join(chans, ", "))")
            options_str = enum_mask_to_string(OptionFlags, options[i])
            println("      Options: $options_str")
        end

        println("\n*NOTE: Connect a trigger source to the TRIG input terminal on HAT 0.")

        try
            println("\nPress 'Enter' to continue")
            readline()
        catch
            error("^C to end program")
        end

        # Start the scan.
        for (i, hat) in enumerate(hats)
            chan_mask = chan_list_to_mask(chans[i])
            mcc172_a_in_scan_start(hat.address, chan_mask, samples_per_channel, options[i])
        end

        println("\nWaiting for trigger ... Press Ctrl-C to stop scan\n")

        try
            # Monitor the trigger status on the master device.
            wait_for_trigger(hats[MASTER])
            # Read and display data for all devices until scan completes
            # or overrun is detected.
            read_and_display_data(hats, chans)

        catch 
            if isa(e, InterruptException)  #KeyboardInterrupt "^C"
                # Clear the "^C" from the display.
                println(CURSOR_BACK_2, ERASE_TO_END_OF_LINE, "\nAborted\n")
                println("$CURSOR_BACK_2 $ERASE_TO_END_OF_LINE \nAborted\n")
            else
                println("\n $e")
            end
        end

    finally
        for hat in hats
            mcc172_a_in_scan_stop(hat.address)
            mcc172_a_in_scan_cleanup(hat.address)
        end
    end
end


"""
    function wait_for_trigger(hat):

Monitor the status of the specified HAT device in a loop until the
triggered status is true or the running status is false.

Args:
hat (mcc172): The mcc172 HAT device object on which the status will
be monitored.

Returns:
Nothing
"""
function wait_for_trigger(hat)
# Read the status only to determine when the trigger occurs.
    is_running = true
    is_triggered = false
    while is_running && !is_triggered
        status = mcc172_status_decode(mcc172_a_in_scan_status(hat.address))
        is_running = status.running
        is_triggered = status.triggered
    end
end

"""
    function read_and_display_data(hats, chans::Matrix{Integer})

Reads data from the specified channels on the specified DAQ HAT devices
and updates the data on the terminal display.  The reads are executed in a
loop that continues until either the scan completes or an overrun error
is detected.

Args:
hats (list[mcc172]): A list of mcc172 HAT device objects.
chans (list[int][int]): A 2D list to specify the channel list for each
mcc172 HAT device.

Returns:
None
"""
function read_and_display_data(hats, chans::Matrix{Integer})
    samples_to_read = 1000
    timeout = 5  # Seconds
    samples_per_chan_read = [0] * DEVICE_COUNT
    total_samples_per_chan = [0] * DEVICE_COUNT
    is_running = true

    # Since the read_request_size is set to a specific value, a_in_scan_read()
    # will block until that many samples are available or the timeout is
    # exceeded.

    # Create blank lines where the data will be displayed
    for _ in 1:(DEVICE_COUNT * 4 + 1)
        println("")
    end

    # Move the cursor up to the start of the data display.
    print("\x1b[[0}A".format(DEVICE_COUNT * 4 + 1))
    print(CURSOR_SAVE)

    while true
        data = [None] * DEVICE_COUNT
        # Read the data from each HAT device.
        for (i, hat) in enumerate(hats)
            resultCode, statuscode, result, samplesread = 
                mcc172_a_in_scan_read(hat.address, samples_to_read, timeout)
            data[i] = result
            status = mcc172_status_decode(statuscode)
            is_running &= status.running
            samples_per_chan_read[i] = int(len(data[i]) / len(chans[i]))
            total_samples_per_chan[i] += samples_per_chan_read[i]

            if read_result.buffer_overrun
                println("\nError: Buffer overrun")
                break
            end
            if read_result.hardware_overrun
                println("\nError: Hardware overrun")
                break
            end
        end

        println(CURSOR_RESTORE) #, end="")

        # Display the data for each HAT device
        for (i, hat) in enumerate(hats)
            println("HAT $i")

            # Print the header row for the data table.
            println("  Samples Read    Scan Count")
            for chan in chans[i]
                println("     Channel $chan")
            end
            println("")

            # Display the sample count information.
            println("           $(samples_per_chan_read[i])
                                          $(total_samples_per_chan[i])")

            # Display the data for all selected channels
            #for chan_idx in range(len(chans[i])):
            #    sample_idx = ((samples_per_chan_read[i] * len(chans[i]))
            #                  - len(chans[i]) + chan_idx)
            #    println("[:>12.5f} V".format(data[i][sample_idx]), end="")

            # Display the RMS voltage for each channel.
            if samples_per_chan_read[i] > 0
                for channel in chans[i]
                    value = calc_rms(data[i], channel, length(chans[i]), samples_per_chan_read[i])
                    println("$(round(value, digits=5)) Vrms ")
                end
                # stdout.flush()
            end
            println("\n")
        end

        if !is_running
            break
        end
    end
end
