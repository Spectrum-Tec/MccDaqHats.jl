# This file contains helper functions for the MCC DAQ HAT Python examples.

#includet("/home/pi/daqhatsJulia/daqhats.jl")    # general daqhats commands
#includet("/home/pi/daqhatsJulia/daqhats172.jl") # MCC172 commands


    # type: (HatIDs) -> int
    """
    function select_hat_device(filter_by_id)
    This function performs a query of available DAQ HAT devices and determines
    the address of a single DAQ HAT device to be used in an example.  If a
    single HAT device is present, the address for that device is automatically
    selected, otherwise the user is prompted to select an address from a list
    of displayed devices.

    Args:
        filter_by_id (int): If this is :py:const:`HatIDs.ANY` return all DAQ
            HATs found.  Otherwise, return only DAQ HATs with ID matching this
            value.

    Returns:
        int: The address of the selected device.

    Raises:
        Exception: No HAT devices are found or an invalid address was selected.

    """
function select_hat_device(filter_by_id::Integer)
    selected_hat_address = Integer[]

    # Get descriptors for all of the available HAT devices.
    hats = hat_list(filter_by_id)
    number_of_hats = length(hats)

    # Verify at least one HAT device is detected.
    if number_of_hats < 1
        error("Error: No HAT devices found")
    elseif number_of_hats == 1
        selected_hat_address = hats[1].address
    else
        # Display available HAT devices for selection.
        for h = 1:number_of_hats
            println("Address $(hats[h].address): $(hats[h].product_name)")
        end
        println()

        println("Select the address of the HAT device to use: ")
        address = parse(Integer, (readline()))

        # Verify the selected address is valid.
        for h in 1:number_of_hats
            if address == hats[h].address
                selected_hat_address = address
                break
            end
        end
    end

    if isempty(selected_hat_address)
        error("Error: Invalid HAT selection")
    end

    return selected_hat_address
end


    # This one not required? but taken from Python
    """
    function enum_mask_to_string(enum_type, bit_mask):
    This function converts a mask of values defined by an IntEnum class to a
    comma separated string of names corresponding to the IntEnum names of the
    values included in a bit mask.

    Args:
        enum_type (Enum): The IntEnum class from which the mask was created.
        bit_mask (int): A bit mask of values defined by the enum_type class.

    Returns:
        str: A comma separated string of names corresponding to the IntEnum
        names of the values included in the mask

    """
function enum_mask_to_string(enum_type::Integer, bit_mask::Integer)
    item_names = String[]
    if bit_mask == 0
        push!(item_names, "DEFAULT")
    end
    for item in enum_type
        if item & bit_mask
            push!(item_names, item.name)
        end
    end

    return join(item_names, ", ")
end

    """
    function chan_list_to_mask(chan_list)

    This function returns an integer representing a channel mask to be used
    with the MCC daqhats library with all bit positions defined in the
    provided list of channels to a logic 1 and all other bit positions set
    to a logic 0.

    Args:
        chan_list(int): A list of channel numbers.

    Returns:
        int: A channel mask of all channels defined in chan_list.

    """
function chan_list_to_mask(chan_list::Vector{T}) where T <: Integer
    chan_mask = zero(UInt8)

    for chan in chan_list
        chan_mask |= 0x01 << chan
    end

    return chan_mask
end


"""
    function validate_channels(channel_set, number_of_channels)

    Raises a ValueError exception if a channel number in the set of
    channels is not in the range of available channels.

    Args:
        channel_set (set): A set of channel numbers.
        number_of_channels (int): The number of available channels.

    Returns:
        None

    Raises:
        ValueError: If there is an invalid channel specified.

"""
function validate_channels(channel_set::Vector{<:Integer}, number_of_channels::Integer)
    # not sure if I have this right
    valid_chans = 0:number_of_channels - 1
    if !issubset(channel_set, valid_chans)
        error("Error: Invalid channel selected - must be $(min(valid_chans)) - $(max(valid_chans))")
    end
end

""" 
    function deinterleaver(data, num_channels, num_samples_per_channel)

Convert interleaved vector to Matrix using reshape and permutedims (probably an expensive way to do it)
"""
function deinterleaver(data::Vector{T}, num_channels::Integer, num_samples_per_channel::Integer) where T <: AbstractFloat
    
    if length(data) == num_channels * num_samples_per_channel
        data = reshape(data, num_channels, num_samples_per_channel)
        data = permutedims(data)
    else
        error("Dimension mismatch")
    end
 
    return data
end

"""
    function deinterleaves(data::Vector{T}, num_channels::Integer, num_samples_per_channel::Integer) where T <: AbstractFloat

Slice the data (not sure of the cost of the slicing)
"""
function deinterleaves(data::Vector{T}, num_channels::Integer, num_samples_per_channel::Integer) where T <: AbstractFloat

    num_samples = length(data)
    # @show(num_channels, num_samples_per_channel, num_samples)
    if num_samples == num_channels * num_samples_per_channel
        datamatrix = similar(data, num_samples_per_channel, num_channels)
        for c in 1:num_channels
            datamatrix[:,c] = data[c:num_channels:num_samples]
        end
    else
        error("Dimension mismatch")
    end
 
    return datamatrix
end


"""
    function deinterleavef(data::Vector{T}, num_channels::Integer, num_samples_per_channel::Integer) where T <: AbstractFloat

Use for loops
"""
function deinterleavef(data::Vector{T}, num_channels::Integer, num_samples_per_channel::Integer) where T <: AbstractFloat

     num_samples = length(data)
    if num_samples == num_channels * num_samples_per_channel
        datamatrix = similar(data, num_samples_per_channel, num_channels)
        for c in 1:num_channels
            @inbounds for d in 1:num_samples_per_channel
                datamatrix[d,c] = data[c + (d-1)*num_channels]
            end
        end
    else
        error("Dimension mismatch")
    end
 
    return datamatrix
end
"""
    function deinterleavesj(data::Vector{T}, num_channels::Integer, num_samples_per_channel::Integer) where T <: AbstractFloat

This is the most performant version on the Raspberry PI
See julia discourse and do a search on deinterleave
"""
function deinterleavesj(data::Vector{T}, num_channels::Integer, num_samples_per_channel::Integer) where T <: AbstractFloat
   if length(data) == num_channels * num_samples_per_channel
       datamatrix = transpose(reshape(a, num_channels, num_samples_per_channel));
   else
       error("Dimension mismatch")
   end
   return datamatrix
end

function deinterleaverg(data::Vector{T}, num_channels::Integer, num_samples_per_channel::Integer) where T <: AbstractFloat
    if length(data) == num_channels * num_samples_per_channel
        datamatrix = transpose(reshape(view(a, :), num_channels, num_samples_per_channel));
    else
        error("Dimension mismatch")
    end
    return datamatrix
 end
 