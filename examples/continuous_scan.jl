using MccDaqHats
using Revise
# using Infiltrator
includet(joinpath(@__DIR__, "utilities.jl"))

mutable struct HatUse
    address::UInt8
    numchanused::Int8
    channel1::Int
    channel2::Int
    chanmask::UInt8
end

READ_ALL_AVAILABLE = -1  # read all available values if -1 in mcc172_a_in_scan_read

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
Enahancements:
Deinterleave data using deinterleave() 
Save data use one of the libraries in github.com/juliaIO, use similar format to matlab format
Check if trigger will work for synchronizing
"""
function continuous_scan()
    samplerate = 20000.0      # Samples per second
    time = 10              # Aquisition time
    readrequestsize = round(Int, samplerate)
    totalsamplesperchan = round(Int, samplerate * time)
    trigger_mode = TRIG_RISING_EDGE
    options = [OPTS_EXTTRIGGER, OPTS_CONTINUOUS] # all Hats
 
    # designed for two mcc172 hats
    # channel enable address boardchannel iepe sens IDstring
    # note that board addresses must be ascending and board channel addresses must be ascending
    config =   [1 true 0 0 true 1000.0 "Channel 1";
                2 true 0 1 true 1000.0 "Channel 2";
                3 true 1 0 true 1000.0 "Channel 3";
                4 true 1 1 true 1000.0 "Channel 4"]

    addresses = UInt8.(unique(config[:,3]))
    MASTER = typemax(UInt8)
    hats = hat_list(HAT_ID_MCC_172)
    chanmask = zeros(UInt8, length(addresses))
    
    if !(Set(UInt8.(config[:,3])) ⊆ Set(getfield.(hats, :address)))
        error("Requested hat addresses not part of avaiable address $(getfield.(hats, :address))")
    end
    
    if !(Set(UInt8.(config[:,4])) == Set(UInt8.([0,1]))) # number of channels mcc172_info().NUM_AI_CHANNELS
        error("Board channel must be 0 or 1")
    end
    
    # maybe more error checks
    
    try
        
        nchan = size(config, 1)
        hatuse = [HatUse(0,0,0,0,0) for _ in 1:length(addresses)]
        ia = 0
        previousaddress = typemax(UInt8)
        for i in 1:nchan
            channel = config[i,1]
            configure = config[i,2]
            address = UInt8(config[i,3])
            boardchannel = UInt8(config[i,4])
            iepe = config[i,5]
            if configure
                if MASTER == typemax(MASTER) # make the first address the MASTER
                    MASTER = address
                end
                if !mcc172_is_open(address)
                    mcc172_open(address)
                    if address ≠ MASTER
                        # Configure the slave clocks.
                        mcc172_a_in_clock_config_write(address, SOURCE_SLAVE, samplerate)
                        # Configure the trigger.
                        mcc172_trigger_config(address, SOURCE_SLAVE, trigger_mode)
                    end
                end
                mcc172_iepe_config_write(address, boardchannel, iepe)

                # mask the channels used & fill in hatuse structure
                if address ≠ previousaddress  # index into hatuse
                    ia += 1
                    previousaddress = address
                end
                hatuse[ia].address = address
                hatuse[ia].numchanused += 0x01
                if boardchannel == 0x00
                    hatuse[ia].channel1 = channel
                elseif boardchannel == 0x01
                    hatuse[ia].channel2 = channel
                else 
                    error("board channel is $boardchannel but must be '0x00 or 0x01")
                end
                hatuse[ia].chanmask |= 0x01 << boardchannel
            end
        end

        # Configure the master clock and start the sync.
        mcc172_a_in_clock_config_write(MASTER, SOURCE_MASTER, samplerate)
        synced = false
        actual_rate = 0
        while !synced
            _source_type, actual_rate, synced = mcc172_a_in_clock_config_read(MASTER)
            if !synced
                sleep(0.005)
            end
        end

        # Configure the master trigger.
        mcc172_trigger_config(MASTER, SOURCE_MASTER, trigger_mode)

        println("MCC 172 multiple HAT example using internal trigger")
        println("    Samples per channel: $(totalsamplesperchan)")
        println("    Requested Sample Rate: $(round(samplerate, digits=3))")
        println("    Actual Sample Rate: $(round(actual_rate, digits=3))")
        println("    Trigger type: $trigger_mode")

        for (i, hu) in enumerate(hatuse)
            println("    HAT: $i")
            println("      Address: $(hu.address)")
            println("      Channels: $(hu.channel1) and $(hu.channel2)")
            # options_str = enum_mask_to_string(OptionFlags, options[i])
            println("      Options: $options")
        end

        # Start the scan.
        for hu in hatuse
            mcc172_a_in_scan_start(hu.address, hu.chanmask, UInt32(samplerate), options)
        end

        # trigger the scan
        trigger(23, duration = 0.05)

        try
            # Monitor the trigger status on the master device.
            wait_for_trigger(MASTER)
            # Read and display data for all devices until scan completes
            # or overrun is detected.
            @show(hatuse, totalsamplesperchan, readrequestsize)
            read_and_save_data(hatuse, totalsamplesperchan, readrequestsize, nchan)

        catch e
            if isa(e, InterruptException)  #KeyboardInterrupt "^C"
                # Clear the "^C" from the display.
                println("$CURSOR_BACK_2 $ERASE_TO_END_OF_LINE \nAborted\n")
            else
                println("\n $e")
            end
        end

    finally
        for (i, hat) in enumerate(hats)
            mcc172_a_in_scan_stop(hat.address)
            mcc172_a_in_scan_cleanup(hat.address)
            mcc172_close(hat.address)
        end
    end
end

function read_and_save_data(hatuse, totalsamplesperchan::Integer, readrequestsize::Integer, nchan)
    total_samples_read = 0
    # read_request_size = READ_ALL_AVAILABLE
    
    # When doing a continuous scan, the timeout value will be ignored in the
    # call to a_in_scan_read because we will be requesting that all available
    # samples (up to the default buffer size) be returned.
    timeout = 5.0
    
    # Read all of the available samples (up to the size of the read_buffer which
    # is specified by the user_buffer_size).  Since the read_request_size is set
    # to -1 (READ_ALL_AVAILA     print("\r$readrequestsize   $total_samples_read")BLE), this function returns immediately with
    # whatever samples are available (up to user_buffer_size) and the timeout
    # parameter is ignored.
    while total_samples_read < totalsamplesperchan
        scanresult = Matrix{Float32}(undef, Int(readrequestsize), nchan)

        for hu in hatuse
            resultcode, statuscode, result, samples_read = 
            mcc172_a_in_scan_read(hu.address, Int32(readrequestsize), hu.numchanused, timeout)
                        
            # Check for an overrun error
            status = mcc172_status_decode(statuscode)
            if status.hardwareoverrun
                println("\n\nHardware overrun\n")
                break
            elseif status.bufferoverrun
                println("\n\nBufoptionsfer overrun\n")
                break
            elseif samples_read ≠ readrequestsize
                error("Samples read was $samples_read and requested size is $readrequestsize")
            end

            if hu.chanmask == 0x01
                chan = hu.channel1
            elseif hu.chanmask == 0x02
                chan = hu.channel2
            elseif hu.chanmask == 0x03
                chan = [hu.channel1 hu.channel2]
            else
                errror("Channel mask is incorrect")
            end
            scanresult[1:readrequestsize,chan] = deinterleave(result, hu.numchanused)
            println("Address $(hu.address) read request size $readrequestsize samples read $samples_read")
        end
        
        total_samples_read += readrequestsize
        
        print("\r$readrequestsize   $total_samples_read")
        
          
        println("\n")
    end
end