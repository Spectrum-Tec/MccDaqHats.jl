#module Mcc172Acquire
#export mcc172acquire, plotarrow

using MccDaqHats
using Arrow
using Dates
using HDF5
using SplitApplyCombine
using Tables
using TypedTables
using TachProcessing
# using Plots
include(joinpath(@__DIR__, "..", "general", "FunPQ.jl"))  

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
	function mcc172acquire(tacq::Table, configtable::Table, write::Bool)
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
function mcc172acquire(tacq::Table, configtable::Table, write::Bool)
    # initialize variables 
    measuredspeedscan :: Union{Float64, Missing} = missing
    measuredspeed :: Union{Float64, Missing} = missing

    # obtain tach information
    primarytach = Int32(only(findall(t -> lowercase(t) == "primary", tcs.tachchan)))
    tachtrigamp = Float32(configtable.thresholdvoltage[primarytach])
    tachcrossdir = lowercase(configtable.slope[primarytach])
    # read TCO as Tach COmpare and TCE as Tach Compare & Equal
    if tachcrossdir == "pos"
        TCO = >
        TCE = >=
    elseif tachcrossdir == "neg"
        TCO = <
        TCE = <=
    else
        error("tachcrossdir is $tusedchanachcrossdir but must be 'pos' or 'neg'")
    end
    @debug @show(TCO, TCE)
    tachppr = Int32(only([primarytach]))
    tachinterpolationmethod = "linear"

    # get acquisition information
    # the lowest board number must be used since it is used for the master and trigger
    # board addresses must be ascending and board channel addresses must be ascending
    currenttime = now() 
    requestfs = Float64(only(tacq.fs))   # Samples per second (200 - 51200 Hz;51200/n n=1-256)
    acqtime = Float32(only(tacq.maxscantime))  # Aquisition time 
    acqrevs = Int64(only(tacq.scanrevolutions))
    timeperblock = Float64(1.0)  # time used to determine number of samples per block - Must stay at ~1.0s for MCC172
    totalsamplesperchan = round(Int, requestfs * acqtime)
    @debug @show(acqrevs, totalsamplesperchan)

    # setup MCC172
    nchan = size(configtable, 1)
    trigger_mode = TRIG_RISING_EDGE
    options = [OPTS_EXTTRIGGER, OPTS_CONTINUOUS] # all Hats
    addresses = UInt8.(unique(configtable.mcc172address[:]))
    MASTER = typemax(UInt8)
    hats = hat_list(HAT_ID_MCC_172)
    hatuse = [HatUse(0,0,0,0,0,0,0) for _ in eachindex(addresses)] #initialize struct for each HAT
    anyiepe = false         # keep track if any used channel is iepe
    usedchan = Vector{Int32}(configtable.channel)
    measchan = 1:length(usedchan)
    @debug @show(hats, usedchan)
    
    if !(Set(UInt8.(configtable.mcc172address)) ⊆ Set(getfield.(hats, :address)))
        error("Requested hat addresses $addresses not part of available addresses $(getfield.(hats, :address))")
    end
    
    if !(Set(UInt8.(configtable.mcc172boardchannel)) ⊆ Set(UInt8.([0,1]))) # number of channels mcc172_info().NUM_AI_CHANNELS
        error("Requested board channels are $(configtable.mcc172boardchannel) but must be 0 or 1")
    end

    predictedfilesize = 4*requestfs*acqtime*nchan  # for Float32
    diskfree = 1024*parse(Float64, split(readchomp(`df /`))[11])
    if predictedfilesize > diskfree
        error("disk free space is $diskfree and predicted file size is $predictedfilesize")
    end
    # maybe more error checks

    # get channel data for arrow metadata information
    channeldata = Pair{String, String}[]
    for i in 1:nchan
        #if configtable.enable[i]
            push!(channeldata, "chan$(i)" => "$(configtable.channel[i])")
            push!(channeldata, "chan$(i)range" => "$(configtable.range[i])")
            push!(channeldata, "chan$(i)coupling" => "$(configtable.coupling[i])")
            push!(channeldata, "chan$(i)iepe" => "$(configtable.iepe[i])")
            push!(channeldata, "chan$(i)label" => "$(configtable.label[i])")
            push!(channeldata, "chan$(i)node" => "$(configtable.node[i])")
            push!(channeldata, "chan$(i)eu" => "$(configtable.engunit[i])")
            push!(channeldata, "chan$(i)eu_per_v" => "$(configtable.eu_per_v[i])")
            push!(channeldata, "chan$(i)tachchan" => "$(configtable.tachchan[i])")
            push!(channeldata, "chan$(i)thresholdvoltage" => "$(configtable.thresholdvoltage[i])")
            push!(channeldata, "chan$(i)slope" => "$(configtable.slope[i])")
            push!(channeldata, "chan$(i)ppr" => "$(configtable.ppr[i])")
            push!(channeldata, "chan$(i)hataddress" => "$(configtable.mcc172address[i])")
            push!(channeldata, "chan$(i)boardchannel" => "$(configtable.mcc172boardchannel[i])")
    end

    try
        ia = 0 # index for used HAT addresses
        previousaddress = typemax(UInt8)  # initialize to unique value
        for i in 1:nchan
            channel = Int(configtable.channel[i])
            address = UInt8(configtable.mcc172address[i])
            boardchannel = UInt8(configtable.mcc172boardchannel[i])
            iepe = Bool(configtable.iepe[i])
            anyiepe = anyiepe || iepe
             
            sensitivity = 1000/configtable.eu_per_v[i]   # mV/eu
            
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
            @debug @show(address, boardchannel, iepe)
            mcc172_iepe_config_write(address, boardchannel, iepe)
            mcc172_a_in_sensitivity_write(address, boardchannel, sensitivity)

            # mask the channels used & fill in hatuse structure
            if address ≠ previousaddress  # index into hatuse
                ia += 1
                previousaddress = address
                hatuse[ia].address = address
            end
            hatuse[ia].numchanused += 0x01
            if boardchannel == 0x00
                hatuse[ia].measchannel1 = measchan[i]
                hatuse[ia].usedchannel1 = usedchan[i]
            elseif boardchannel == 0x01
                hatuse[ia].measchannel2 = measchan[i]
                hatuse[ia].usedchannel2 = usedchan[i]
            else 
                error("board channel is $boardchannel but must be '0x00' or '0x01'")
            end
            hatuse[ia].chanmask |= 0x01 << boardchannel
        end
        @debug @show(hatuse[ia])

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
        readrequestsize = round(Int32, timeperblock * actual_fs)

        # Configure the master trigger.
        mcc172_trigger_config(MASTER, SOURCE_MASTER, trigger_mode)

        @info begin
            println("MCC 172 multiple HAT data acquisition using internal trigger")
            println("    Samples per channel: $(totalsamplesperchan)")
            println("    Requested Acquisition time: $acqtime")
            println("    Requested Sample Rate: $(round(requestfs, digits=3))")
            println("    Actual Sample Rate: $(round(actual_fs, digits=3))")
            println("    Trigger type: $trigger_mode")

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
        end

        # Vector for storing metadata
        measurementdata = [
            "measprog" => "acquiremcc172.jl",
            "meastime" => string(now()),
            "meascomments" => "",
            "measrequestedfs" => "$requestfs",
            "measfs" => "$actual_fs",
            "measbs" => "$readrequestsize",
            "meastriggermode" => "$trigger_mode"]
            
        # open Arrow file
        write && begin
            arrowfilename = "temp" * Dates.format(currenttime, "yyyy-mm-ddTHH:MM:SS") * ".arrow"
            arrowfilename = joinpath(homedir(), "data", arrowfilename)
            global writer = open(Arrow.Writer, arrowfilename; metadata=reverse([measurementdata; channeldata]))
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
        scanresult = Matrix{Float32}(undef, readrequestsize, nchan)
        previoustachamp = zero(scanresult[1])
        pulses = 0
        tachcrosstimefirst::Union{Float32, Missing} = missing
        tachcrosstimelast::Union{Float32, Missing} = missing
        
        #= Save arrow file to HDF5 and delete arrow file
        fh5 = h5open(filename, "w")
        d = create_dataset(fh5, "data", Float32, (totalsamplesperchan, nchan))
        # scanresult = Matrix{Float32}(undef, readrequestsize, nchan) 
        =#
        
        @debug println("Setup Complete, Start sample read")
        while total_samples_read < totalsamplesperchan && (pulses - 1)//tachppr < acqrevs
            
            # read and process data a HAT at a time
            for hu in hatuse
                resultcode, statuscode, result, samples_read = 
                mcc172_a_in_scan_read(hu.address, readrequestsize, hu.numchanused, timeout)
                
                # Check for an overrun error
                status = mcc172_status_decode(statuscode)
                if status.hardwareoverrun
                    error("Hardware overrun")
                elseif status.bufferoverrun
                    error("Bufoptionsfer overrun")
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
                @debug @show(chan)
    
                # deinterleave the data and put in temporary matrix or hdf dataset
                scanresult[1:readrequestsize,chan] = deinterleave(result, hu.numchanused)

                @debug println("Data read from hat $(hu.address)")
           end

            # convert matrix to a Table and write to Arrow formatted Data
            write && Arrow.write(writer, Tables.table(scanresult))
            total_samples_read += readrequestsize
            @debug @show(total_samples_read)

          # process the primary tach channel
            tachdata = view(scanresult, :, primarytach)
            previoustachamp = ifelse(m == 0, tachdata[1], previoustachamp)
            @debug @show(previoustachamp, maximum(tachdata))
            
            # @show(tachtrigamp, tachcrossdir, tachppr, tachinterpolationmethod)
            tachcrosstime = Vector{Float32}(undef, 0)
            for (k, td) in enumerate(tachdata)
                # TCO and TCE defined above for pos & neg slope
                if TCO(td, tachtrigamp) && TCE(tachtrigamp, previoustachamp)
                    frac = ifelse(tachinterpolationmethod == "linear",
                        (tachtrigamp - previoustachamp)/(td - previoustachamp), zero(td))
                    # subtract 1 for start at zero, and subtract 1 for reference at previoustachamp
                    tachtime = (m*Float64(readrequestsize) + k + frac - 2)/actual_fs
                    # println("index $(m*readrequestsize + k) frac $frac time $tachtime s")
                    # @infiltrate
                    push!(tachcrosstime, tachtime)
                end
                previoustachamp = td
            end

            @debug @show(tachcrosstime)
            l = length(tachcrosstime)

            # first tach crossing
            if ismissing(tachcrosstimefirst) && l > 0
                tachcrosstimefirst = tachcrosstime[1]
            end

            if l > 0 
                pulses += l
                tachcrosstimelast = tachcrosstime[end]
            end
            @debug @show((pulses - 1)//tachppr)

            if l > 1 
                measuredspeedscan = (l - 1)/(tachcrosstime[end] - tachcrosstime[begin])/tachppr
            else
                measuredspeedscan = missing
            end
            @debug @show(l, measuredspeedscan)

            # @infiltrate
            # tc = tachcross(tachdata, actual_fs; crossdir=tachcrossdir) #; 
            #    trigamp=tachtrigamp, crossdir=tachcrossdir, ppr=tachppr, interpolationmethod=tachinterpolationmethod)
            m += 1
            print("\r $(m*timeperblock) of $acqtime s with speed $(round(measuredspeedscan,digits=2)) and pulses $pulses    ")
        end
        if ismissing(tachcrosstimefirst) || ismissing(tachcrosstimelast) || tachcrosstimefirst == tachcrosstimelast
            @debug println("Speed cannot be calculated")
            measuredspeed = missing
        else
            measuredspeed = (pulses - 1)/(tachcrosstimelast - tachcrosstimefirst)/tachppr
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
        write && close(writer)  # close arrow file
        # close(fh5)     # close HDF5 file
        println("Exit Acquisition with Average Speed of $(round(measuredspeed,digits=2))")
    end
    return measuredspeed
end


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

#end #module
