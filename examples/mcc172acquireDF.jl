module Mcc172Acquire
export mcc172acquire, plotarrow

using MccDaqHats
using Arrow
using Dates
using DataFrames
using HDF5
using Tables
using Revise
using Plots

writer = nothing

mutable struct HatUse
    address::UInt8
    numchanused::Int8
    measchannel1::UInt8
    measchannel2::UInt8
    usedchannel1::UInt8
    usedchannel2::UInt8
    chanmask::UInt8
end

const global READ_ALL_AVAILABLE = -1  # set read_request_size = READ_ALL_AVAILABLE to read complete buffer
const global CURSOR_BACK_2 = "\x1b[2D"
const global ERASE_TO_END_OF_LINE = "\x1b[0K"

"""
	function mcc172acquire()
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
        print("File '$filename' exists, reenter to overwrite or enter new name  (no quotes):  ")
        filename = readline()
    end

    requestfs = Float64(51200/1)   # Samples per second (200 - 51200 Hz;51200/n n=1-256)
    acqtime = Float64(20.0)        # Aquisition time 
    timeperblock = Float64(1.0)    # time used to determine number of samples per block: Must stay at ~1.0s for RPI 4
    totalsamplesperchan = round(Int, requestfs * acqtime)
    trigger_mode = TRIG_RISING_EDGE
    options = [OPTS_EXTTRIGGER, OPTS_CONTINUOUS] # all Hats

    # designed for two mcc172 hats
    # note that board addresses must be ascending and board channel addresses must be ascending
    # The sensitivity is specified in mV / engineering unit (mV/eu).
    # config contains the following columns (customize as appropriate)
    # enable channelnum IDstring node datatype eu iepe sens address boardchannel Comments
    config =   [true 1 "Channel tach" "1x" "Volt" "V" false 1.0 0 0 "";
                true 2 "Channel acc" "2x" "Acc" "m/s^2" true 10.0 0 1 "";
                false 3 "Channel 3" "3x" "Acc" "m/s^2" true 100.0 1 0 "";
                false 4 "Channel 4" "4x" "Acc" "m/s^2" true 100.0 1 1 ""]::Matrix{Any}

    # below code is experimental to see if it makes the code more type stable (Check with JET)
    config = DataFrame(enable=Bool.(config[:,1]),
                    channelnum=Int.(config[:,2]),
                    IDstring=String.(config[:,3]),
                    node=String.(config[:,4]),
                    datatype=String.(config[:,5]),
                    eu=String.(config[:,6]),
                    iepe=Bool.(config[:,7]),
                    sens=Float64.(config[:,8]),
                    address=UInt8.(config[:,9]),
                    boardchannel=UInt8.(config[:,10]),
                    Comments=String.(config[:,11]))

    nchan = size(config, 1)
 
    # get channel data for arrow metadata information
    channeldata = Pair{String, String}[]
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
    hatuse = [HatUse(0,0,0,0,0,0,0) for _ in eachindex(addresses)] #initialize struct for each HAT
    usedchan = Int[]
    anyiepe = false         # keep track if any used channel is iepe

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
        error("Requested hat addresses $addresses not part of available addresses $(getfield.(hats, :address))")
    end
    
    if !(Set(UInt8.(config[:,10])) ⊆ Set(UInt8.([0,1]))) # number of channels mcc172_info().NUM_AI_CHANNELS
        error("Requested board channels are $(config[:,10]) must be 0 or 1")
    end

    predictedfilesize = 4*requestfs*acqtime*nchan  # for Float32
    diskfree = 1024*parse(Float64, split(readchomp(`df /`))[11])
    if predictedfilesize > diskfree
        error("disk free space is $diskfree and predicted file size is $predictedfilesize")
    end
    # maybe more error checks

    try
        ia = 0 # index for used HAT addresses
        previousaddress = typemax(UInt8)  # initialize to unique value
        for i in 1:nchan
            channel = Int(config[i,2])
            configure = Bool(config[i,1])
            address = UInt8(config[i,9])
            boardchannel = UInt8(config[i,10])
            iepe = Bool(config[i,7])
            anyiepe = anyiepe || iepe
             
            sensitivity = Float64(config[i,8])
            
            if configure
                if MASTER == typemax(MASTER) # make the first address the MASTER
                    MASTER = address
                end
                if !mcc172_is_open(address) # perform HAT specific functions
                    mcc172_open(address)
                    if address ≠ MASTER # slave specific functions
                        # Configure the slave clocks
                        mcc172_a_in_clock_config_write(address, SOURCE_SLAVE, requestfs)
                        # Configure the trigger
                        mcc172_trigger_config(address, SOURCE_SLAVE, trigger_mode)
                    end
                end
                # @show(address, boardchannel, iepe)
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
                    hatuse[ia].measchannel1 = channel
                    hatuse[ia].usedchannel1 = usedchan[i]
                elseif boardchannel == 0x01
                    hatuse[ia].measchannel2 = channel
                    hatuse[ia].usedchannel2 = usedchan[i]
                else 
                    error("board channel is $boardchannel but must be '0x00 or 0x01")
                end
                hatuse[ia].chanmask |= 0x01 << boardchannel
            end
        end

        # if a HAT is not used, remove it from the hat_list
        for i in length(hatuse):-1:1
            if iszero(hatuse[i].numchanused)
                deleteat!(hatuse, i)
            end
        end

       # Let iepe settle if it is used
        if anyiepe
            sleep(3.5)
        end

        # Configure the master clock and start the sync.
        mcc172_a_in_clock_config_write(MASTER, SOURCE_MASTER, requestfs)
        # The previous command should sync the HATs, the following verifies this
        synced = false
        actual_fs = Float64(0.0) # initialize
        while !synced
            _source_type, actual_fs, synced = mcc172_a_in_clock_config_read(MASTER)
            if !synced
                sleep(0.005)
            end
        end

        # number of samples read per block
        readrequestsize = round(Int, timeperblock * actual_fs)

        # Configure the master trigger.
        mcc172_trigger_config(MASTER, SOURCE_MASTER, trigger_mode)

        println("MCC 172 multiple HAT data acquisition using internal trigger")
        println("    Samples per channel: $(totalsamplesperchan)")
        println("    Requested Acquisition time: $time")
        println("    Requested Sample Rate: $(round(requestfs, digits=3))")
        println("    Actual Sample Rate: $(round(actual_fs, digits=3))")
        println("    Trigger type: $trigger_mode")
        println("    Requested Acquisition Time: $acqtime")
        for (i, hu) in enumerate(hatuse)
            if hu.chanmask == 0x00
                chanprint = "0"
            elseif hu.chanmask == 0x01
                chanprint = "1"
            elseif hu.chanmask == 0x03
                chanprint = "0 & 1"
            end
            println("    HAT: $i with Address $(hu.address)")
            println("      Channels: $chanprint")
            # options_str = enum_mask_to_string(OptionFlags, options[i])
            println("      Options: $options")
        end

        # Vector for storing metadata
        measurementdata = [
            "measprog" => "continuous_scan.jl",
            "starttime" => string(now()),
            "meascomments" => "",
            "measrequestedfs" => "$requestfs",
            "measfs" => "$actual_fs",
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
        m = 0
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
                    mcc172_a_in_scan_read(hu.address, readrequestsize, hu.numchanused, timeout)
                # Can do a check on result_code
                # Check for an overrun error
                status = mcc172_status_decode(statuscode)
                if status.hardwareoverrun
                    error("Hardware overrun")
                elseif status.bufferoverrun
                    error("Buffer overrun")
                elseif !status.triggered
                    error("Measurement not triggered")
                elseif !status.running
                    error("Measurement not running")
                elseif samples_read ≠ readrequestsize
                    error("Samples read was $samples_read and requested size is $readrequestsize")
                end
    
                # Get the right column(s) for the channel(s) on this hat
                if hu.chanmask == 0x01
                    chan = hu.measchannel1
                elseif hu.chanmask == 0x02
                    chan = hu.measchannel2
                elseif hu.chanmask == 0x03
                    chan = [hu.measchannel1 hu.measchannel2]
                else
                    error("Channel mask is incorrect")
                end
    
                # deinterleave the data and put in temporary matrix or hdf dataset
                # scanresult[1:readrequestsize,chan] = deinterleave(result, hu.numchanused)
                if arrow
                    scanresult[1:readrequestsize,chan] = deinterleave(result, hu.numchanused)
                else
                    [d[m*readrequestsize + 1:(m+1)*readrequestsize,chan[j]] = deinterleave(result, hu.numchanused)[:,j] for j in hu.numchanused]
                end
            end
            
            # convert matrix to a Table and write to Arrow formatted Data
            if arrow
                Arrow.write(writer, Tables.table(scanresult))
            else
                # allready done 
            end

            m += 1
            total_samples_read += readrequestsize
            print("\r $(m*timeperblock) of $acqtime s")  
        end
        println("\nData written, Cleanup underway")
    catch e # KeyboardInterrupt
        # this is probably rough around the edges
        if isa(e, InterruptException)
            # Clear the "^C" from the display.
            println("$CURSOR_BACK_2 $ERASE_TO_END_OF_LINE \nAborted\n")
        else
            println("\n $e")
        end

    finally
        @debug @show(hats, hatuse)
        for hat in hatuse
            println("Stop & cleanup hat $(hat.address)")
            mcc172_a_in_scan_stop(hat.address)
            mcc172_a_in_scan_cleanup(hat.address)
            # Turn off IEPE supply
            for boardchannel in 0:1
                # @show(hat.address, boardchannel)
                open = mcc172_is_open(hat.address)
                # @show(open)
                mcc172_iepe_config_write(hat.address, boardchannel, false)
            end
            mcc172_close(hat.address)
        end
        if arrow
            close(writer)  # close arrow file
        else
            close(fh5)
        end
        println("\n")
    end
end

mcc172acquire() = mcc172acquire("test.arrow")

function plotarrow(filename)
    data = Arrow.Table(filename)
    datadict = Arrow.getmetadata(data)
    colmetadata = Arrow.getmetadata(data.Column1)  # but in Arrow.jl returns nothing till issue resolved
    Δt = 1/parse(Float64, datadict["measfs"])
    time = range(0, step=Δt, length=length(data[1]))
    plot(time, [data[1] data[2]])
end

#=
begin
    fh5 = h5open(filename, "r")
    data = read_dataset(fh5, "data")
    close(fh5)
end
=#

end #module
