using Revise

# Constants
const DEVICE_COUNT = 2
const MASTER = 0
const CURSOR_SAVE = "\x1b[s"
const CURSOR_RESTORE = "\x1b[u"
const CURSOR_BACK_2 = "\x1b[2D"
const ERASE_TO_END_OF_LINE = "\x1b[0K"

"""
function chandict
Dictionary of channel definitions (addresses)
"""
function chandict()
chdict = Dict[Symbol, UInt8}(
    :CHAN0 => 0x01 << 0,
    :CHAN1 => 0x01 << 1,
    :CHAN2 => 0x01 << 2,
    :CHAN3 => 0x01 << 3,
    :CHAN4 => 0x01 << 4,
    :CHAN5 => 0x01 << 5,
    :CHAN6 => 0x01 << 6,
    :CHAN7 => 0x01 << 7)
end

"""
    function get_iepe()
Get IEPE enable from the user.
"""
function get_iepe()
    while true
        # Wait for the user to enter a response
        println("IEPE enable [y or n]?  ")
        response = readline()

        # Check for valid response
        if lowercase(response) == "y"
            return true
        elseif lowercase(response) == "n"
            return false
        else
            # Ask again.
            println("Invalid response try again.")
        end
    end
end


"""
	function select_hat_devices(filter_by_id, number_of_devices)

This function performs a query of available DAQ HAT devices and determines
the addresses of the DAQ HAT devices to be used in the example.  If the
number of HAT devices present matches the requested number of devices,
a list of all mcc172 objects is returned in order of address, otherwise the
user is prompted to select addresses from a list of displayed devices.

Args:
filter_by_id (int): If this is :py:const:`HatIDs.ANY` return all DAQ
    HATs found.  Otherwise, return only DAQ HATs with ID matching this
    value.
number_of_devices (int): The number of devices to be selected.

Returns:
list[mcc172]: A list of mcc172 objects for the selected devices
(Note: The object at index 0 will be used as the master).

Raises:
HatError: Not enough HAT devices are present.

"""
function select_hat_devices(filter_by_id, number_of_devices)

selected_hats = zeros(Integer, number_of_devices)

# Get descriptors for all of the available HAT devices.
hats = hat_list(filter_by_id=filter_by_id)
number_of_hats = length(hats)

# Verify at least one HAT device is detected.
if number_of_hats < number_of_devices:
    error("Error: This example requires $number_of_devices MCC 172 HATs - 
                found $number_of_hats")
elseif number_of_hats == number_of_devices
   for i in range(number_of_devices):
       push!(selected_hats, hats[i].address)
   end
else
   # Display available HAT devices for selection.
   for h in hats
       println("Address $(hats[h].address): $(hats[h].product_name) sep=")
       println("")
   end

for device in 1:number_of_devices
    valid = false
    while !valid
        println("Enter address for HAT device $device")
        address = parse(Int, readline())

        # Verify the selected address exists.
        if any(address .== [hats[h].address for h = 1:length(hats)])
            valid = True
        else
            println("Invalid address - try again")
        end

        # Verify the address was not previously selected
        if any(address .== [selected_hats[h].address for h = 1:length(hats)])
            println("Address already selected - try again")
            valid = False
        end

        if valid
            push!(selected_hats ,address)
    end
end
return selected_hats
end


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
        for i, hat in enumerate(hats):
            validate_channels(chans[i], hat.info.NUM_AI_CHANNELS)
        end 

        # Turn on IEPE supply?
        iepe_enable = get_iepe()

        for i, hat in enumerate(hats):
            for channel in chans[i]:
                # Configure IEPE.
                mcc172_iepe_config_write(channel, iepe_enable)
            end
            if hat.address != MASTER:
                # Configure the slave clocks.
                mcc172_a_in_clock_config_write(hat.address, :SOURCE_SLAVE, sample_rate)
                # Configure the trigger.
                mcc172_trigger_config(hat.address, :SOURCE_SLAVE, trigger_mode)
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
        println("    Requested Sample Rate: $(round(sample_rate, digits=3)))
        println("    Actual Sample Rate: $(round(actual_rate, digits=3)))
        println("    Trigger type: $trigger_mode")

        for i, hat in enumerate(hats):
            println("    HAT: $i)
            println("      Address: $(hat.address))
            println("      Channels: $(join(chans, ", "))")
            options_str = enum_mask_to_string(OptionFlags, options[i])
            println("      Options: $options_str")
        end

        println("\n*NOTE: Connect a trigger source to the TRIG input terminal on HAT 0.")

        try
            println("\nPress "Enter" to continue")
            readline()
        end

        # Start the scan.
        for i, hat in enumerate(hats):
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
            else
                println("\n", error)
            end
        end

    finally
        for hat in hats
            mcc172_a_in_scan_stop(hat.address)
            mcc172_a_in_scan_cleanup(hat.address)
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
    while is_running && !is_triggered:
        status = mcc172_a_in_scan_status(hat.address)
        is_running = status.running
        is_triggered = status.triggered
    end
end

""" 
    function calc_rms(data, channel, num_channels, num_samples_per_channel)

Calculate RMS value from a block of samples. 
"""
function calc_rms(data::Matrix{T}, channel::Integer, num_channels::Integer, num_samples_per_channel::Integer)
    value = 0.0
    index = channel
    for i in 1:num_samples_per_channel
        value += (data[i] * data[i]) / num_samples_per_channel
        index += num_channels
    end

    return sqrt(value)
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
    for _ in range(DEVICE_COUNT * 4 + 1):
        println("")
    # Move the cursor up to the start of the data display.
    println("\x1b[[0}A".format(DEVICE_COUNT * 4 + 1), end="")
    println(CURSOR_SAVE, end="")

    while true
        data = [None] * DEVICE_COUNT
        # Read the data from each HAT device.
        for i, hat in enumerate(hats):
            read_result = mcc172_a_in_scan_read(hat.address, samples_to_read, timeout)
            data[i] = read_result.data
            is_running &= read_result.running
            samples_per_chan_read[i] = int(len(data[i]) / len(chans[i]))
            total_samples_per_chan[i] += samples_per_chan_read[i]

            if read_result.buffer_overrun:
                println("\nError: Buffer overrun")
                break
            end
            if read_result.hardware_overrun:
                println("\nError: Hardware overrun")
                break
            end
        end

        println(CURSOR_RESTORE, end="")

        # Display the data for each HAT device
        for i, hat in enumerate(hats):
            println("HAT [0}:".format(i))

            # Print the header row for the data table.
            println("  Samples Read    Scan Count", end="")
            for chan in chans[i]:
                println("     Channel", chan, end="")
            end
            println("")

            # Display the sample count information.
            println("[0:>14}[1:>14}".format(samples_per_chan_read[i],
                                          total_samples_per_chan[i]), end="")

            # Display the data for all selected channels
            #for chan_idx in range(len(chans[i])):
            #    sample_idx = ((samples_per_chan_read[i] * len(chans[i]))
            #                  - len(chans[i]) + chan_idx)
            #    println("[:>12.5f} V".format(data[i][sample_idx]), end="")

            # Display the RMS voltage for each channel.
            if samples_per_chan_read[i] > 0
                for channel in chans[i]
                    value = calc_rms(data[i], channel, len(chans[i]),samples_per_chan_read[i])
                    println("[:10.5f}".format(value), "Vrms ", end="")
                end
                stdout.flush()
            end
            println("\n")

        if !is_running
            break
end

function calc_rms(data, channel::UInt8, num_channels::UInt8, num_samples_per_channel::UInt32)
    value = 0.0;
    for i = 1:num_samples_per_channel
        index = (i - 1) * num_channels + channel;
        value += (data[index] * data[index]) / num_samples_per_channel;
    end
    
    return sqrt(value);
end
