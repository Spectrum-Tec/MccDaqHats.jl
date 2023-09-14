using MccDaqHats
using Arrow
using Dates
using HDF5
using Tables
using Revise
# includet(joinpath(@__DIR__, "utilities.jl"))

writer = nothing

mutable struct HatUse
    address::UInt8
    numchanused::Int8
    channel1::Int
    channel2::Int
    usedchannel1::Int
    usedchannel2::Int
    chanmask::UInt8
end

READ_ALL_AVAILABLE = -1  # set read_request_size = READ_ALL_AVAILABLE to read complete buffer

mcc172acquire() = mcc172acquire("test.arrow")

"""
mcc172acquire()
    Purpose:
        Get synchronous data from multiple MCC 172 devices and store to file.
        Until this is precompiled the first time it is run may error due to 
        timing issues.  Try again immediately and it should work.

    Description:
        The config array needs to be edited to setup the data acquisition.
        The comment just above it explains what each column is.  The data is
        stored as an arrow or hdf5 file.

        The user supplied column meta data has a bug so the meta data is stored
        for the file in this example.  
        See https://github.com/apache/arrow-julia/issues/485.

        This example demonstrates acquiring data synchronously from multiple
        MCC 172 devices.  This is done using the shared clock and trigger
        options.  The master HAT is the HAT with the lowest address.  An 
        internal trigger source from GPIO pin 23 (hardcoded) is connected by 
        wire to the TRIG terminal on the master MCC 172 device.  This allows 
        multiple HATS to acquire simultaneously without a user supplied trigger.
        The clock and trigger on the master device are configured for 
        SOURCE_MASTER and the remaining devices are configured for SOURCE_SLAVE.
        
        The data is deinterleaved using deinterleave().
        The data can be stored in arrow format or hdf5 format.  The arrow format
        allows CNTL+C to stop data acquisition early with file size for the data
        recorded.  HDF5 initializes the file at the beginning of acquisition.
        Arrow includes metadata about the acquisition and the channels.  This has
        not been implemented on HDF5.
"""
function mcc172acquire(filename::String)
    arrow = true       # Select between arrow or hdf5 file format
    
    if isfile(filename)
        # determine whether to overwrite file or ask for another filename
        # use extension .arrow or .h5
        print("File '$filename' exists, reenter to overwrite or enter new name:  ")
        filename = readline()
    end
    requestfs = 51200.0 / 128   # Samples per second
    time = 5.0                  # Aquisition time 
    timeperblock = 1.0          # time used to determine number of samples per block
    totalsamplesperchan = round(Int, requestfs * time)
    trigger_mode = TRIG_RISING_EDGE
    options = [OPTS_EXTTRIGGER, OPTS_CONTINUOUS] # all Hats

    # designed for two mcc172 hats
    # note that board addresses must be ascending and board channel addresses must be ascending
    # The sensitivity is specified in mV / engineering unit (mV/eu).
    # config contains the following columns (customize as appropriate)
    # enable channel# IDstring node datatype eu iepe sens address boardchannel Comments
    config =   [true 1 "Channel 1" "1x" "Acc" "m/s^2" true 100.0 0 0 "";
                true 2 "Channel 2" "2x" "Acc" "m/s^2" true 100.0 0 1 "";
                true 3 "Channel 3" "3x" "Acc" "m/s^2" true 100.0 1 0 "";
                true 4 "Channel 4" "4x" "Acc" "m/s^2" true 100.0 1 1 ""]

    nchan = size(config, 1)
 
    # get channel data for arrow metadata information
    channeldata = []
    for i in 1:nchan
        if config[i,1]
            push!(channeldata, "chan$(i)" => "$(config[i,2])")
            push!(channeldata, "chan$(i)ID" => "$(config[i,3])")
            push!(channeldata, "chan$(i)node" => "$(config[i,4])")
            push!(channeldata, "chan$(i)datatype" => "$(config[i,5])")
            push!(channeldata, "chan$(i)eu" => "$(config[i,6])")
            push!(channeldata, "chan$(i)iepe" => "$(config[i,7])")
            push!(channeldata, "chan$(i)sensitivty" => "$(config[i,8])")
            push!(channeldata, "chan$(i)hataddress" => "$(config[i,9])")
            push!(channeldata, "chan$(i)hatchannel" => "$(config[i,10])")
            push!(channeldata, "chan$(i)comments" => "$(config[i,11])")
        end
    end
    
    addresses = UInt8.(unique(config[:,9]))
    MASTER = typemax(UInt8)
    hats = hat_list(HAT_ID_MCC_172)
    # chanmask = zeros(Int8, length(addresses)) # not used
    usedchan = Int[]

    # Vector of used channels
    ii = 0
    for i in 1:nchan
        enable = config[i,1]
        if enable
            ii += 1
            push!(usedchan, ii)
        end
    end
    
    if !(Set(UInt8.(config[:,9])) ⊆ Set(getfield.(hats, :address)))
        error("Requested hat addresses not part of avaiable address $(getfield.(hats, :address))")
    end
    
    if !(Set(UInt8.(config[:,10])) == Set(UInt8.([0,1]))) # number of channels mcc172_info().NUM_AI_CHANNELS
        error("Board channel must be 0 or 1")
    end

    predictedfilesize = 4*requestfs*time*nchan  # for Float32
    diskfree = 1024*parse(Float64, split(readchomp(`df /`))[11])
    if predictedfilesize > diskfree
        error("disk free space is $diskfree and predicted file size is $predictedfilesize")
    end
    # maybe more error checks

    try
        # initialize struct
        hatuse = [HatUse(0,0,0,0,0,0,0) for _ in 1:length(addresses)] #initialize struct for each HAT
        ia = 0 # index for used HAT addresses
        previousaddress = typemax(UInt8)  # initialize to unique value
        for i in 1:nchan
            channel = config[i,2]
            configure = config[i,1]
            address = UInt8(config[i,9])
            boardchannel = UInt8(config[i,10])
            iepe = config[i,7]
     
            
            if configure
                if MASTER == typemax(MASTER) # make the first address the MASTER
                    MASTER = address
                end
                if !mcc172_is_open(address) # perform HAT specific functions
                    mcc172_open(address)
                    if address ≠ MASTER
                        # Configure the slave clocks.
                        mcc172_a_in_clock_config_write(address, SOURCE_SLAVE, requestfs)
                        # Configure the trigger.
                        mcc172_trigger_config(address, SOURCE_SLAVE, trigger_mode)
                    end
                end
                mcc172_iepe_config_write(address, boardchannel, iepe)
                # (address, requestfs, boardchannel, iepe, sensitivity)
                mcc172_a_in_sensitivity_write(address, boardchannel, sensitivity)

                # mask the channels used & fill in hatuse structure
                if address ≠ previousaddress  # index into hatuse
                    ia += 1
                    previousaddress = address
                    hatuse[ia].address = address
                end
                hatuse[ia].numchanused += 0x01
                if boardchannel == 0x00
                    hatuse[ia].channel1 = channel
                    hatuse[ia].usedchannel1 = usedchan[i]
                elseif boardchannel == 0x01
                    hatuse[ia].channel2 = channel
                    hatuse[ia].usedchannel2 = usedchan[i]
                else 
                    error("board channel is $boardchannel but must be '0x00 or 0x01")
                end
                hatuse[ia].chanmask |= 0x01 << boardchannel
            end
        end

        # Configure the master clock and start the sync.
        mcc172_a_in_clock_config_write(MASTER, SOURCE_MASTER, requestfs)
        # The previous command should sync the HATs, the following verifies this
        synced = false
        actual_rate = Float64(0.0) # initialize
        while !synced
            _source_type, actual_rate, synced = mcc172_a_in_clock_config_read(MASTER)
            if !synced
                sleep(0.005)
            end
        end

        # number of samples read per block
        readrequestsize = round(Int, timeperblock * actual_rate)

        # Configure the master trigger.
        mcc172_trigger_config(MASTER, SOURCE_MASTER, trigger_mode)

        println("MCC 172 multiple HAT example using internal trigger")
        println("    Samples per channel: $(totalsamplesperchan)")
        println("    Requested Sample Rate: $(round(requestfs, digits=3))")
        println("    Actual Sample Rate: $(round(actual_rate, digits=3))")
        println("    Trigger type: $trigger_mode")

        for (i, hu) in enumerate(hatuse)
            println("    HAT: $i")
            println("      Address: $(hu.address)")
            println("      Channels: $(hu.channel1) and $(hu.channel2)")
            # options_str = enum_mask_to_string(OptionFlags, options[i])
            println("      Options: $options")
        end

        # Vector for storing metadata
        measurementdata = [
            "measprog" => "continuous_scan.jl",
            "meastime" => string(now()),
            "meascomments" => "",
            "measrequestedfs" => "$requestfs",
            "measfs" => "$actual_rate",
            "measbs" => "$readrequestsize",
            "meastriggermode" => "$trigger_mode"]
    
    
        # open Arrow or HDF5 file
        if arrow
            global writer = open(Arrow.Writer, filename; metadata=reverse([measurementdata; channeldata]))
        else
            fh5 = h5open(filename, "w")
        end

        # Start the scan.
        for hu in hatuse
            mcc172_a_in_scan_start(hu.address, hu.chanmask, UInt32(requestfs), options)
        end

        # trigger the scan after it has started
        trigger(23, duration = 0.05)

        # Monitor the trigger status on the master device.
        wait_for_trigger(MASTER)

        # Read and save data for all enabled channels until scan completes or overrun is detected
        total_samples_read = 0

        # When doing a continuous scan, the timeout value will be ignored in the
        # call to a_in_scan_read because we will be requesting that all available
        # samples (up to the default buffer size) be returned.
        timeout = 5.0
        i = 0
        if arrow
            scanresult = Matrix{Float32}(undef, Int(readrequestsize), nchan)
        else
            d = create_dataset(fh5, "data", Float32, (totalsamplesperchan, nchan))
            # scanresult = Matrix{Float32}(undef, Int(readrequestsize), nchan) 
        end

        while total_samples_read < totalsamplesperchan
            
            # read and process data a HAT at a time
            for hu in hatuse
                resultcode, statuscode, result, samples_read = 
                    mcc172_a_in_scan_read(hu.address, Int32(readrequestsize), hu.numchanused, timeout)
                            
                # Check for an overrun error
                status = mcc172_status_decode(statuscode)
                if status.hardwareoverrun
                    println("Hardware overrun")
                    break
                elseif status.bufferoverrun
                    println("Bufoptionsfer overrun")
                    break
                elseif !status.triggered
                    println("Measurement not triggered")
                    break
                elseif !status.running
                    println("Measurement not running")
                    break
                elseif samples_read ≠ readrequestsize
                    println("Samples read was $samples_read and requested size is $readrequestsize")
                    break
                end
    
                # Get the right column(s) for the channel(s) on this hat
                if hu.chanmask == 0x01
                    chan = hu.usedchannel1
                elseif hu.chanmask == 0x02
                    chan = hu.usedchannel2
                elseif hu.chanmask == 0x03
                    chan = [hu.usedchannel1 hu.usedchannel2]
                else
                    error("Channel mask is incorrect")
                end
    
                # deinterleave the data and put in temporary matrix or hdf dataset
                # scanresult[1:readrequestsize,chan] = deinterleave(result, hu.numchanused)
                if arrow
                    scanresult[1:readrequestsize,chan] = deinterleave(result, hu.numchanused)
                else
                    [d[i*readrequestsize + 1:(i+1)*readrequestsize,chan[j]] = deinterleave(result, hu.numchanused)[:,j] for j in hu.numchanused]
                end
            end
            
            # convert matrix to a Table and write to Arrow formatted Data
            if arrow
                Arrow.write(writer, Tables.table(scanresult))
            else
                # allready done 
            end
            
            i += 1
            total_samples_read += readrequestsize
            print("\r $(i*timeperblock) of $time s")  
        end
    catch e
        # this is probably rough around the edges
            # Clear the "^C" from the display.
            println("$CURSOR_BACK_2 $ERASE_TO_END_OF_LINE \nAborted\n")
        else
            println("\n $e")
        end

    finally
        # @show(hats)
        for (i, hat) in enumerate(hats)
            # @show(i, hat.address)
            # Turn off IEPE supply
            for channel in channels
                mcc172_iepe_config_write(address, channel, false)
            end
            mcc172_a_in_scan_stop(hat.address)
            mcc172_a_in_scan_cleanup(hat.address)
            mcc172_close(hat.address)
            # @show(hat.address)
        end
        if arrow
            close(writer)  # close arrow file
        else
            close(fh5)
        end
        println("\n")
    end
end

# data = Arrow.Table(filename)
# datadict = Arrow.getmetadata(data)
# colmetadata = Arrow.getmetadata(data.Column1)  # but in Arrow.jl returns nothing till issue resolved
# Δt = 1/parse(Float64, datadict["measfs"])
# time = range(0, step=Δt, length=length(data[1]))
# using Plots
# plot(time, [data[1],data[2],data[3]])

#=
begin
    fh5 = h5open(filename, "r")
    data = read_dataset(fh5, "data")
    close(fh5)
end
=#
