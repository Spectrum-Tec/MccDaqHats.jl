using Revise
includet("/home/pi/daqhatsJulia/daqhats.jl")    # general daqhats commands
includet("/home/pi/daqhatsJulia/daqhats172.jl") # MCC172 commands

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

DEVICE_COUNT = 0x02
MASTER = 0x00

#define CURSOR_SAVE "\x1b[s"
#define CURSOR_RESTORE "\x1b[u"

#=
# array of structures as follows
struct HatInfo
    address::UInt8 		# The board address.
    id::String 			# The product ID, one of [HatIDs](@ref HatIDs)
    version::UInt16 		# The hardware version
    product_name::String	# The product name
end
=#

# HAT device addresses - determined at runtime
h172 = hat_list(:HAT_ID_MCC_172)
num_h172 = hat_list(:HAT_ID_MCC_172, :count)
#@show(h172, num_h172)

# channel mask for one channel is 0b01 and for both channels is 0b11
# for mcc172_a_in_scan_start()

chan_mask = [0b11; 0b11]  # array for both channels

options = Set{Symbol}([:OPTS_EXTTRIGGER])
samples_per_channel = UInt32(10240)
sample_rate = 10240.0               # Samples per second
trigger_mode = :TRIG_RISING_EDGE

# I think this is just to show how it is done
mcc172_num_channels = mcc172_info().NUM_AI_CHANNELS
#@show(mcc172_num_channels)

# mcc172_a_in_scan_status() and mcc172_a_in_scan_read() variables
scan_status = zeros(UInt16, DEVICE_COUNT)
buffer_size = samples_per_channel * mcc172_num_channels # UInt32
data = Array{Float64}(undef,DEVICE_COUNT, buffer_size)  # note the row major order
samples_read = zeros(UInt32, DEVICE_COUNT)
samples_to_read = Int32(1000)          # in C int32_t 
timeout = 5.0                   #seconds
samples_available = UInt32(0)
result = Int32(0)
chan_count = Array{Int32}(undef, DEVICE_COUNT)
chans = Array{Int32}(undef, DEVICE_COUNT, mcc172_num_channels)
device = Int32(0)
i = 0
total_samples_read = zeros(Int32, DEVICE_COUNT)
data_display_line_count = DEVICE_COUNT * 4       # const in C
is_running = UInt16(0)
is_triggered = UInt16(0)
scan_status_all = UInt16(0)

chan_display = Array{String}(undef, DEVICE_COUNT)

#=  initialized in C
    char options_str[256];
    char display_string[256] = "";
    char data_display_output[1024] = "";
    char c;
    uint8_t synced;
    uint8_t clock_source;
=#

actual_sample_rate = Float64(0.0)

# get structure (address, id, version, product_name)
hats = hat_list(:HAT_ID_MCC_172, DEVICE_COUNT)
device_address_list = Vector{UInt8}(undef,DEVICE_COUNT)
for i = 1:DEVICE_COUNT
    device_address_list[i] = hats[i].address
end
#@show(hats, device_address_list)
    
try
    for device in device_address_list
        # @show(device)
        # open board
        result = mcc172_open(device)
        # @show(result, trigger_mode)
        # @show((device == MASTER) ? :SOURCE_MASTER : :SOURCE_SLAVE)
        # Configure the trigger

        result = mcc172_trigger_config(device, 

            (device == MASTER) ? :SOURCE_MASTER : :SOURCE_SLAVE,

            trigger_mode)
        # @show(result)

        # configure the clock (slaves only)
        if device != MASTER
	    result = mcc172_a_in_clock_config_write(device, 
		:SOURCE_MASTER, sample_rate)
            # @show(result)
        end
    end
    # configure the master clock last so the clocks are synchronized
    result = mcc172_a_in_clock_config_write(MASTER, :SOURCE_MASTER, sample_rate)
catch
    for device in device_address_list
	# scan_stop
	mcc172_a_in_scan_stop(device)
        # scan_cleanup
	mcc172_a_in_scan_cleanup(device)
        println("Catch me if you can")
    end
end
println("location 1")		
# Wait for sync to complete (there is a more julian way to do this)
sync = UInt8(MASTER)
while sync == 0
    clock_source, actual_sample_rate, sync = mcc172_a_in_clock_config_read(MASTER)
    sleep(0.005)
end
println("location 1")		
 
print("\nMCC 172 multiple device example using shared clock and trigger options\n")
print("    Functions demonstrated:\n")
print("      mcc172_trigger_config\n")
print("      mcc172_a_in_clock_config_write\n")
print("      mcc172_a_in_clock_config_read\n")
print("      mcc172_a_in_scan_start\n")
print("      mcc172_a_in_scan_status\n")
print("      mcc172_a_in_scan_read\n")
print("      mcc172_a_in_scan_stop\n")
print("    Samples per channel: $samples_per_channel\n")
print("    Requested Sample Rate: $sample_rate [Hz]\n")
print("    Actual Sample Rate: $actual_sample_rate [Hz]\n")
print("    Trigger mode: $trigger_mode\n")

#@show(device_address_list)
for (i, device) in enumerate(device_address_list)
    #@show(i, device)
    print("    MCC 172 $i:\n")
    print("      Address: $device\n")
    print("      Channels: $chan_mask\n")  # should pretty this
end

print("\nConnect a trigger source to the TRIG input terminal on device at address $device_address_list[1].\n");
print("\nPress 'Enter' to continue\n")

c = readline()

# Start the scans
for (i,device) in enumerate(device_address_list)
    result = mcc172_a_in_scan_start(device, chan_mask[i],
            samples_per_channel, options);
end

print("Waiting for trigger ... Press 'Cntl C' to abort\n\n");

# Check the master status in a loop to determine when the trigger occurs
is_running = true
is_triggered = false
while (is_running && !is_triggered);
    sleep(0.010);
    result, status_code, samples_available = mcc172_a_in_scan_status(MASTER)
    status = mcc172_status_decode(status_code)
    #@show(status_code, status, typeof(status))
    # :IS_RUNNING -> 0x0008
    is_running = status_code & 0x0008 == 0x0008 ? true : false
    # :IS_TRIGGERED -> 0x0004
    is_triggered = status_code & 0x0004 == 0x0004 ? true : false
end

 error("didn't catch me!!!")
end
#=

if (is_running && is_triggered)
    print("Acquiring data ... Press 'Enter' to abort\n\n");
    # Create blank lines where the data will be displayed.
    for i = 1:data_display_line_count
        print("\n");
    end
    # Move the cursor up to the start of the data display
    print("\x1b[%dA", data_display_line_count + 1);
    # Save the cursor position
    print(CURSOR_SAVE);
else
    print("Aborted\n\n");
    is_running = 0;
end
    while (is_running)
    {
        for (device = 0; device < DEVICE_COUNT; device++)
        {
            # Read data
            result = mcc172_a_in_scan_read(address[device], 
                &scan_status[device], samples_to_read, timeout, data[device],
                buffer_size, &samples_read[device]);
            STOP_ON_ERROR(result);
            # Check for overrun on any one device
            scan_status_all |= scan_status[device];
            # Verify the status of all devices is running
            is_running &= (scan_status[device] & STATUS_RUNNING);
        }

        if ((scan_status_all & STATUS_HW_OVERRUN) == STATUS_HW_OVERRUN)
        {
            fprint(stderr, "\nError: Hardware overrun\n");
            break;
        }
        if ((scan_status_all & STATUS_BUFFER_OVERRUN) == STATUS_BUFFER_OVERRUN)
        {
            fprint(stderr, "\nError: Buffer overrun\n");
            break;
        }

        # Restore the cursor position to the start of the data display
        print(CURSOR_RESTORE);
        
        for (device = 0; device < DEVICE_COUNT; device++)
        {
            strcpy(data_display_output, "");

            sprintf(display_string, "HAT %d:\n", device);
            strcat(data_display_output, display_string);

            # Display the header row for the data table
            strcat(data_display_output, "  Samples Read    Scan Count");
            for (i = 0; i < chan_count[device]; i++)
            {
                sprintf(display_string, "     Channel %d", chans[device][i]);
                strcat(data_display_output, display_string);
            }
            strcat(data_display_output, "\n");

            # Display the sample count information for the device
            total_samples_read[device] += samples_read[device];
            sprintf(display_string, "%14d%14d", samples_read[device],
                total_samples_read[device]);
            strcat(data_display_output, display_string);

            # Display the data for all active channels
            if (samples_read[device] > 0)
            {
                for (i = 0; i < chan_count[device]; i++)
                {
                    # Calculate and display RMS voltage of the input data
                    sprintf(display_string, "%9.3f Vrms",
                        calc_rms(data[device], i, chan_count[device],
                            samples_read[device]));
                    strcat(data_display_output, display_string);
                }
            }

            strcat(data_display_output, "\n\n");
            printf(data_display_output);
        }

        fflush(stdout);

        if (enter_press())
        {
            printf("Aborted\n\n");
            break;
        }
    }

stop:
    # Stop and cleanup
    for (device = 0; device < DEVICE_COUNT; device++)
    {
        result = mcc172_a_in_scan_stop(address[device]);
        print_error(result);
        result = mcc172_a_in_scan_cleanup(address[device]);
        print_error(result);
        
        # Restore clock and trigger to local source
        result = mcc172_a_in_clock_config_write(address[device], 
            SOURCE_LOCAL, sample_rate);
        print_error(result);
        
        result = mcc172_trigger_config(address[device], 
            SOURCE_LOCAL, trigger_mode);
        print_error(result);

        result = mcc172_close(address[device]);
        print_error(result);
    }

    return 0;
}

=#

function calc_rms(data, channel::UInt8, num_channels::UInt8, num_samples_per_channel::UInt32)
    value = 0.0;
    for i = 1:num_samples_per_channel
        index = (i - 1) * num_channels + channel;
        value += (data[index] * data[index]) / num_samples_per_channel;
    end
    
    return sqrt(value);
end
