module Mcc172Acquire
export mcc172acquire, plotarrow

using MccDaqHats
using Arrow
using Dates
using HDF5
using Tables
using TypedTables
using Plots
using XLSX

mutable struct HatUse
    address::UInt8                          # HAT address
    numchanused::Int8                       # number of channels used on this HAT
    channel1::Int8                          # channel in the system
    channel2::Int8                          # channel in the system
    measchannel1::Union{UInt8, Missing}     # channel number in system that is enabled
    measchannel2::Union{UInt8, Missing}     # channel number in system that is enabled
    chanmask::UInt8                         # for hardware 
end

"""
	mcc172acquire(filename::String; configfile::String="PIconfig.xlsx")
Purpose:
Get synchronous data from multiple MCC 172 devices and store to file.
Until this is precompiled the first time it is run may error due to 
timing issues.  Try again immediately and it should work.

Description:
The xlsx file needs to be edited to setup the data acquisition.
The spreadsheet should be self explanatory.  The data is
stored as an arrow or hdf5 file.  Metadata storage only works 
for arrow files.  This file uses TypedTables rather than DataFrames.

The user supplied column metadata in arrow files has a bug so the 
meta data is stored for the file in this example.  
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
function mcc172acquire(filename::String; configfile::String="PIconfig.xlsx")
    writer = nothing
    
    if isfile(filename)
        # determine whether to overwrite file or ask for another filename
        # use extension .arrow or.h5
        print("File '$filename' exists, reenter to overwrite or enter new name (no quotes):  ")
        filename = readline()
    end

    # Initialize sheet ranges
    configsheet = "config"
    configrange = "B2:B6"
    chansheet = "chanconfig"

    info = XLSX.readdata(configfile, configsheet * "!" * configrange)
    
    # get acquisition information
    # the lowest board number must be used since it is used for the master and trigger
    # board addresses must be ascending and board channel addresses must be ascending
    requestfs = Float64(info[2])   # Samples per second (200 - 51200 Hz;51200/n n=1-256)
    acqtime = Float64(info[1])     # Acquisition time 
    timeperblock = Float64(info[3])    # time used to determine number of samples per block - Must stay at ~1.0s for MCC172 on PI 4
    filetype = info[4]             # Select between arrow or hdf5 file format
    arrow = lowercase(filetype) == "arrow" ? true : false
    prec = info[5]
    dprecision = Dict("Float32"=>Float32,"Float64"=>Float64)
    WP = dprecision[prec]          # write precision
    totalsamplesperchan = round(Int, requestfs * acqtime)

    # setup MCC172
    trigger_mode = TRIG_RISING_EDGE
    options = [OPTS_EXTTRIGGER, OPTS_CONTINUOUS] # all Hats
    
    config = Table(XLSX.readtable(configfile, chansheet; infer_eltypes=true))
    nchan = size(config, 1)
    
    # Convert comment from missing to a blank string
    for i = 1:nchan
        if ismissing(config[i].comment)
            config[i].comment = ""
        end
    end

    # test validity of file types
    isa(config.enable, Vector{Bool}) || error("Enable column must be Boolean")
    isa(config.channelnum, Vector{Int}) || error("Channel Number column must be Integers")
    isa(config.idstring, Vector{String}) || error("IDstring column must be Strings")
    isa(config.nodes, Vector{String}) || error("Node column must be Number and Direction")
    isa(config.nodes, Vector{String}) || error("Node column must be Number and Direction")
    isa(config.datatype, Vector{String}) || error("Datatype column must be Number and Direction")
    isa(config.eu, Vector{String}) || error("Engineering Unit (EU) column must be Number and Direction")
    isa(config.iepe, Vector{Bool}) || error("IEPE column must be Boolean")
    isa(config.var"sens [mV/eu]", Vector{<:Number}) || error("IEPE column must be Numbers")
    isa(config.comments, Vector{String}) || error("Comments must be Strings")

    MASTER = typemax(UInt8)
    hats = hat_list(HAT_ID_MCC_172)
    addresses =[hat.address for hat in hats]
    hatuse = [HatUse(0,0,0,0,missing,missing,0) for _ in eachindex(addresses)] #initialize struct for each HAT
    anyiepe = false         # keep track if any used channel is iepe
    nchanused = sum(config.enable)

    nchanused <= 2*length(hats) || error("number of channels is $nchanused but acquistion is limited to $(2*length(hats))")
    
    # Ensure one address is 0x00  (Do I need this?)
    any(UInt8.(addresses) .== 0x00) || error("At least one channel from board address 0x00 must be used")

# Ensure enough free disk space
if WP == Float64
    wp = 8
elseif WP == Float32
    wp = 4
else
    error("Write precision is $WP but must be 'Float64' or 'Float32'")
end
predictedfilesize = wp*requestfs*acqtime*nchanused
    diskfree = diskstat().available
    if predictedfilesize > diskfree
        error("disk free space is $(round(diskfree,sigdigits=3)) 
            and predicted file size is $(round(predictedfilesize, sigdigits=3))")
    end
    # maybe more error checks

    config = Table(config; hataddress = [addresses[(i+1)÷2] for i in 1:nchan])
    config = Table(config; hatchannel = [UInt8(mod((i+1),2)) for i in 1:nchan])

    try
        ia = 0 # index for used HAT addresses
        im = 0 # index for measured channels
        usedchan = Int[]
        previousaddress = typemax(UInt8)  # initialize to unique value
        for i in 1:nchan
            channel = i
            configure = Bool(config.enable[i])
            address = UInt8(config.address[i])
            boardchannel = UInt8(config.boardchannel[i])
            iepe = Bool(config.iepe[i])
            anyiepe = anyiepe || iepe
            sensitivity = Float64(config.sens[i])
            if boardchannel == 0x00
                hatuse[(i+1)÷2].channel1 = channel
            elseif boardchannel == 0x01
                hatuse[(i+1)÷2].channel2 = channel
            else 
                error("board channel is $boardchannel but must be '0x00' or '0x01'")
            end

            configure || continue
            im += 1
            push!(usedchan, i)
            if MASTER == typemax(MASTER) # make the first address the MASTER (board at address 0x00)
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
                hatuse[ia].measchannel1 = im
            elseif boardchannel == 0x01
                hatuse[ia].measchannel2 = im
            else 
                error("board channel is $boardchannel but must be '0x00' or '0x01'")
            end
            hatuse[ia].chanmask |= 0x01 << boardchannel
        end

        # if a HAT is not used, remove it from the hat_list
        for i in length(hatuse):-1:1
            if iszero(hatuse[i].numchanused)
                deleteat!(hatuse, i)
            end
        end

    # get channel data for arrow metadata information
    channeldata = Pair{String, String}[]
    for i in usedchan
        push!(channeldata, "chan$(i)" => "$(config.channelnum[i])")
        push!(channeldata, "chan$(i)ID" => "$(config.idstring[i])")
        push!(channeldata, "chan$(i)node" => "$(config.node[i])")
        push!(channeldata, "chan$(i)datatype" => "$(config.datatype[i])")
        push!(channeldata, "chan$(i)eu" => "$(config.eu[i])")
        push!(channeldata, "chan$(i)iepe" => "$(config.iepe[i])")
        push!(channeldata, "chan$(i)sensitivty" => "$(config.var"sens [mV/er]"[i])")
        push!(channeldata, "chan$(i)hataddress" => "$(config.hataddress[i])")
        push!(channeldata, "chan$(i)hatchannel" => "$(config.hatchannel[i])")
        push!(channeldata, "chan$(i)comments" => "$(config.comments[i])")
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

        # Let iepe settle if it is used
        anyiepe && sleep(6)

        # number of samples read per block
        readrequestsize = round(Int32, timeperblock * actual_fs)

        # Configure the master trigger
        mcc172_trigger_config(MASTER, SOURCE_MASTER, trigger_mode)

        println("MCC 172 multiple HAT example using internal trigger")
        println("    Samples per channel: $(totalsamplesperchan)")
        println("    Requested Acquisition time: $acqtime")
        println("    Requested Sample Rate: $(round(requestfs, digits=3))")
        println("    Actual Sample Rate: $(round(actual_fs, digits=3))")
        println("    Acquisition Block Size: $readrequestsize")
        println("    Trigger type: $trigger_mode")
        println("    Requested acquisition time: $acqtime")
        println("    File type to write to is $filetype")

        for (i, hu) in enumerate(hatuse)
            if hu.chanmask == 0x01
                chanprint = "0"
            elseif hu.chanmask == 0x02
                chanprint = "1"
            elseif hu.chanmask == 0x03
                chanprint = "0 & 1"
            end
            println("    HAT: $i with Address $(hu.address)")
            println("      Channels: $chanprint")
            println("      Options: $options")
        end

        # Vector for storing metadata
        measurementdata = [
            "measprog" => "Mcc172AcquireTT.jl",
            "starttime" => string(now()),
            "meascomments" => "",
            "measrequestedfs" => "$requestfs",
            "measfs" => "$actual_fs",
            "measbs" => "$readrequestsize",
            "meastriggermode" => "$trigger_mode"]
    
        # open Arrow or HDF5 file
        if arrow
            writer = open(Arrow.Writer, filename; metadata=reverse([measurementdata; channeldata]))
            scanresult = Matrix{WP}(undef, readrequestsize, nchanused)
        else
            writer = h5open(filename, "w")
            d = create_dataset(writer, "data", Float32, (totalsamplesperchan, nchanused))
        end

        # Create the buffers for reading the data from the HATS for single or two channels
        buffer1 = Vector{Float64}(undef, readrequestsize)
        buffer2 = Vector{Float64}(undef, 2readrequestsize)

        # Start the scan
        for hu in hatuse
            mcc172_a_in_scan_start(hu.address, hu.chanmask, UInt32(requestfs), options)
        end

        # trigger the scan after it has started
        trigger(23, duration = 0.020)

        # Monitor the trigger status on the master device.
        wait_for_trigger(MASTER)

        # When doing a continuous scan, the timeout value will be ignored in the
        # call to mcc172_a_in_scan_read because we will be requesting that all available
        # samples (up to the default buffer size) be returned.
        timeout = 5.0
        total_samples_read = 0
        m = 0
        println("Hardware setup complete - Start measuring data")

        # Read and save data for all enabled channels until scan completes or overrun is detected
        while total_samples_read < totalsamplesperchan
            
            # read and process data a HAT at a time
            for hu in hatuse
                # determine if one or two channels worth of buffer is required
                result = ifelse(hu.numchanused == 1, buffer1, buffer2)

                # read the buffer
                resultcode, statuscode, samples_read = 
                    mcc172_a_in_scan_read!(result, hu.address, Int32(readrequestsize), hu.numchanused, timeout)
                            
                # Check result_code for errors
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
                # HDF write already done 
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
        for hat in hatuse
            mcc172_a_in_scan_stop(hat.address)
            mcc172_a_in_scan_cleanup(hat.address)
            # Turn off IEPE supply
            for boardchannel in 0:1
                open = mcc172_is_open(hat.address)
                mcc172_iepe_config_write(hat.address, boardchannel, false)
            end
            mcc172_close(hat.address)
        end
        if arrow
            close(writer)  # close arrow file
        else
            close(writer)
        end
        println("\n")
    end
end

mcc172acquire() = mcc172acquire("test.arrow")

"""
    function plotarrow(filename::String)

Plot an arrow file collected by mcc172acquire
"""
function plotarrow(filename::String; channels=1)
    inspectdr()
    data = Arrow.Table(filename)
    datadict = Arrow.getmetadata(data)
    colmetadata = Arrow.getmetadata(data.Column1)  # but in Arrow.jl returns nothing till issue resolved
    Δt = 1/parse(Float64, datadict["measfs"])
    nr=length(data[1])
    acqtime = range(0, step=Δt, length=nr)
    # plot(acqtime, [data[1] data[2]])
    # plot(acqtime, data[1:2])  # Cannot index into Arrow this way
    
    plotdata = Matrix{Float32}(undef, nr, length(channels))
    for (i, c) in enumerate(channels)
        plotdata[1:nr, i] = data[c]
    end
    plot(acqtime, plotdata)
end

#=
begin
    fh5 = h5open(filename, "r")
    data = read_dataset(fh5, "data")
    close(fh5)
    Δt = 1/parse(Float64, datadict["measfs"])
   d
=#

end #module