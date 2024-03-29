# functions that are common to the scan examples or are helper functions

""" 
    function calc_rms(data, channel, num_channels, num_samples_per_channel)

Calculate RMS value from a block of samples that are interleaved from an mcc172 HAT.
Note that deinterleaving data is extremely fast and allows the standard DSP rms 
function to be used.  This would be a better approach but differs from the C and 
python implementations.
"""
function calc_rms(data::Vector{T}, channel::Integer, num_channels::Integer, num_samples_per_channel::Integer) where T <: AbstractFloat
    # @show(channel, num_channels, num_samples_per_channel)
    value = 0.0
    index = channel
    #@show(length(data), value, index, channel, num_channels, num_samples_per_channel)
    for i in 1:num_samples_per_channel
        value += (data[index] * data[index]) / num_samples_per_channel
        index += num_channels
    end

    return sqrt(value)
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
filter_by_id (int): If this is :ANY` return all DAQ HATs found.  
Otherwise, return only DAQ HATs with ID matching this value.
number_of_devices (int): The number of devices to be selected.

Returns:
list[mcc172]: A list of HatInfo structs for the selected devices
(Note: The struct at index 0 will be used as the master).

Raises:
HatError: Not enough HAT devices are present.

"""
function select_hat_devices(filter_by_id::HatIDs, number_of_devices::Integer)

    selected_hats = HatInfo[]

    # Get descriptors for all of the available HAT devices.
    hats = hat_list(filter_by_id)
    number_of_hats = length(hats)

    # Verify at least one HAT device is detected.
    if number_of_hats < number_of_devices
        error("Error: This example requires $number_of_devices MCC 172 HATs - found $number_of_hats")
    elseif number_of_hats == number_of_devices
        # Select all the devices
        for i in 1:number_of_devices
            push!(selected_hats, hats[i])
        end
    else
        # Display available HAT devices for selection.
        for h in 1:length(hats)
            println("Address $(hats[h].address) for hat $(hats[h].product_name)")
        end

        # Select the devices
        for device in 1:number_of_devices
            valid = false
            while !valid
                println("Enter address for HAT device $device")
                address = parse(Int, readline())
                
                # Verify the selected address exists.
                if any(address .== [hats[h].address for h = 1:length(hats)])
                    valid = true
                else
                    println("Invalid address - try again")
                end

                # Verify the address was not previously selected
                if !isempty(selected_hats) && any(address .== [selected_hats[h].address for h = 1:length(hats)])
                    println("Address already selected - try again")
                    valid = false
                end

                if valid
                    for h in eachindex(hats) 
                        if address == hats[h].address
                            push!(selected_hats ,hats[h])
                        end
                    end
                end
            end
        end
    end
    return selected_hats
end

"""
    function trigger_dialog()
Manual or GPIO based trigger for synchronization
"""
function trigger_dialog()
while(true)

    println("GPIO trigger connected ? Y/n")
    ans = readline()
    @show(ans)
    # @infiltrate
    if ans == "" || lowercase(ans[1]) == 'y'
        trigger(23, duration = 0.05)

        break
    elseif lowercase(ans[1]) == 'n'
        println("\n*NOTE: Connect a trigger source to the TRIG input terminal on HAT 0.")
        try
            println("\nPress 'Enter' to continue")
            readline()
        catch
            error("^C to end program")
        end
        break
    else
        println("Incorrect response try again")
    end
end
end



"""
    function wait_for_trigger(address)

Monitor the status of the specified HAT device in a loop until the
triggered status is true or the running status is false.

Args:
hat (mcc172): The mcc172 HAT device object on which the status will
be monitored.

Returns:
Nothing
"""
function wait_for_trigger(address)
# Read the status only to determine when the trigger occurs.
    is_running = true
    is_triggered = false
    while is_running && !is_triggered
        sleep(0.01)
        result_code, status_code, samples_per_channel = mcc172_a_in_scan_status(address)
        status = mcc172_status_decode(status_code)
        is_running = status.running
        is_triggered = status.triggered
    end
    return nothing
end

