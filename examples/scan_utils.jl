# functions that are common to the scan examples or are helper functions

""" 
    function calc_rms(data, channel, num_channels, num_samples_per_channel)

Calculate RMS value from a block of samples. 
"""
function calc_rms(data::Matrix{T}, channel::Integer, num_channels::Integer, num_samples_per_channel::Integer) where T <: AbstractFloat
    value = 0.0
    index = channel
    for i in 1:num_samples_per_channel
        value += (data[i] * data[i]) / num_samples_per_channel
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
function select_hat_devices(filter_by_id::Symbol, number_of_devices::Integer)

selected_hats = zeros(Integer, number_of_devices)

# Get descriptors for all of the available HAT devices.
hats = hat_list(filter_by_id)
number_of_hats = length(hats)

# Verify at least one HAT device is detected.
if number_of_hats < number_of_devices
    error("Error: This example requires $number_of_devices MCC 172 HATs - found $number_of_hats")
elseif number_of_hats == number_of_devices
   for i in 1:number_of_devices
       push!(selected_hats, hats[i].address)
   end
else
   # Display available HAT devices for selection.
   for h in hats
       println("Address $(hats[h].address): $(hats[h].product_name)\n")
   end
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
end
return selected_hats
end

