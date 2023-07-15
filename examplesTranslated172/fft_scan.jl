using MccDaqHats
using DelimitedFiles
using FFTW
using Revise
# using Infiltrator
includet(joinpath(@__DIR__, "scan_utils.jl"))

#Constants
CURSOR_BACK_2 = "\x1b[2D"
ERASE_TO_END_OF_LINE = "\x1b[0K"

"""
MCC 172 Functions Demonstrated:
    mcc172_iepe_config_write
    mcc172_a_in_clock_config_write
    mcc172_a_in_clock_config_read
    mcc172_a_in_scan_start
    mcc172_a_in_scan_read_numpy
    mcc172_a_in_scan_stop

Purpose:    
    Perform finite acquisitions on both channels, calculate the FFTs, and
    display peak information.

Description:    
    Acquires blocks of analog input data for both channels then performs
    FFT calculations to determine the frequency content. The highest    
    frequency peak is detected and displayed, along with harmonics. The
    time and frequency data are saved to CSV files.

    This example requires the NumPy library.

"""        
function fft_scan()

    channels = [0, 1]
    num_channels = length(channels)
    channel_mask = chan_list_to_mask(channels)

    samples_per_channel = 12800
    scan_rate = 51200.0
    options = [OPTS_DEFAULT]

    try
        # Select an MCC 172 HAT device to use.
        hat = select_hat_devices(HAT_ID_MCC_172, 1)
        address = hat[1].address

        println("\nSelected MCC 172 HAT device at address $address")

        # Turn on IEPE supply?
        iepe_enable = get_iepe()

        mcc172_open(address)
        for channel in channels
            mcc172_iepe_config_write(address, channel, iepe_enable)
        end

        # Configure the clock and wait for sync to complete.
        mcc172_a_in_clock_config_write(address, SOURCE_LOCAL, scan_rate)

        synced = false
        actual_scan_rate = 0.0
        while !synced
            (_source_type, actual_scan_rate, synced) = mcc172_a_in_clock_config_read(address)
            if !synced
                sleep(0.005)
            end
        end

        println("\nMCC 172 Multi channel FFT example")
        println("    Functions demonstrated:")
        println("         mcc172_iepe_config_write")
        println("         mcc172_a_in_clock_config_write")
        println("         mcc172_a_in_clock_config_read")
        println("         mcc172_a_in_scan_start")
        println("         mcc172_a_in_scan_read_numpy")
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
        channel_mask = chan_list_to_mask(channels)
        mcc172_a_in_scan_start(address, channel_mask, samples_per_channel, options)

        try
            read_and_display_data(address, samples_per_channel, num_channels, scan_rate)
            
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
    return nothing
end


""" Hann window function. """
function window(index, max_index)
    return 0.5 - 0.5*cos(2π*index / max_index)
end

""" Hann window compensation factor. """
function window_compensation()
    return 2.0
end

""" Calculate a real-only FFT, returning the spectrum in dBFS. """
function calculate_real_fft(data)
    nsam, nchan = size(data)
    win_data = Matrix{Float64}(undef, nsam, nchan)

    # Apply the window and normalize the time data.
    info = mcc172_info()
    max_v = info.AI_RANGE_MAX
    for j in 1:nchan
        for i in 1:nsam
            win_data[i,j] = window(i, nsam) * data[i,j] / max_v
        end
    end

    # Perform the FFT.
    out = fft(win_data)

    # Convert the complex results to real and convert to dBFS.
    spectrum = Matrix{Float64}(undef, nsam, nchan)

    for j in nchan
        for i in 1:nsam
            if i == 1
                # Don't multiply DC value times 2
                spectrum[i,j] = 20*log10(window_compensation() *
                    sqrt(real(out[i]) ^ 2 + imag(out[i]) ^ 2) / nsam)
            else
                spectrum[i,j] = 20*log10(window_compensation() * 2 *
                    sqrt(real(out[i]) ^ 2 + imag(out[i]) ^ 2) / nsam)
            end
        end
    end

    return spectrum
end

"""
Interpolate between the bins of an FFT peak to find a more accurate
frequency.  bin1 is the FFT value at the detected peak, bin0 and bin2
are the values from adjacent bins above and below the peak. Returns
the offset value from the index of bin1.
"""
function quadratic_interpolate(bin0, bin1, bin2)
    y_1 = abs(bin0)
    y_2 = abs(bin1)
    y_3 = abs(bin2)

    result = (y_3 - y_1) / (2 * (2 * y_2 - y_1 - y_3))

    return result
end

""" 
Return a given number with the appropriate suffix as a string. 
"""
function add_suffix(index::Integer)
    if index == 1
        suffix = "st"
    elseif index == 2
        suffix = "nd"
    elseif index == 3
        suffix = "rd"
    else
        suffix = "th"
    end

    return string(i) * suffix
end

"""
Wait for all of the scan data, perform an FFT, find the peak frequency,
and display the frequency information.  Only supports 1 channel in the data.

Args:
hat (mcc172): The mcc172 HAT device object.
samples_per_channel: The number of samples to read for each channel.

Returns:
Nothing
"""
function read_and_display_data(address, samples_per_channel, channels, scan_rate)
 
    timeout = 5.0

    # Wait for all the data, and read it as an array.
    resultcode, status, read_result, samples_read_per_channel = 
        mcc172_a_in_scan_read(address, Int32(samples_per_channel), num_channels, timeout)
    
    # Separate the data by channel (deinterleave)
    read_data = deinterleave(read_result, length(channels))

    for channel in channels
        print("===== Channel:    $channel\n")

        # Calculate the FFT
        spectrum = calculate_real_fft(read_data[:, channel+1])

        # Calculate dBFS and find peak.
        f_i = 0.0
        peak_index = 0
        peak_val = -1000.0


        # Save data to CSV file
        logname = "fft_scan_" * string(i) * ".csv"
        io = open(logname, "w")
        writedlm("Time data (V), Frequency (Hz), Spectrum (dBFS)\n")

        for (i, spec_val) in enumerate(spectrum)
            # Find the peak value and index.
            if spec_val > peak_val
                peak_val = spec_val
                peak_index = i
            end

            # Save to the CSV file.
            writedlm(read_data[i], f_i, spec_val)

            f_i += scan_rate / samples_per_channel
        end

        close(io)

        # Interpolate for a more precise peak frequency.
        peak_offset = quadratic_interpolate(
            spectrum[peak_index - 1], spectrum[peak_index], spectrum[peak_index + 1])
        peak_freq = ((peak_index + peak_offset) * scan_rate /
                     samples_per_channel)
        println("Peak: $(round(peak_val, digits = 2)) dBFS at $(round(peak_freq, digitis = 2)) Hz")

        # Find and display harmonic levels.
        i = 2
        h_freq = 0
        nyquist = scan_rate / 2.0
        while (i < 8) && (h_freq <= nyquist)
            # Stop when frequency exceeds Nyquist rate or at the 8th harmonic.
            h_freq = peak_freq * i
            if h_freq <= nyquist
                h_index = floor(h_freq * samples_per_channel / scan_rate + 0.5)
                h_val = spectrum[h_index]
                print(" $(add_suffix(i)) harmonic: $h_val dBFS at $h_freq Hz")
            end
            i += 1
        end

        println("Data and FFT saved in $logname")
    end
end
