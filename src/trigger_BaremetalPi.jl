using BaremetalPi

#Preferred Implementation but needs work for RPI 5

"""
    function trigger(pin::Int; duration::Real=0.050)

The pin numbers to use are the GPIO pin numbers.  Thus 23 is 
GPIO23 which is the Pi pin number 16.  The pin number reference
is available from the web or the Pi command pinout.

Alternative Packages to try:
    https://github.com/notinaboat/PiGPIOMEM.jl/blob/master/src/PiGPIOMEM.jl
    PiGPIO.jl
    etc.
"""
function trigger(pin::Int; duration::Number = 0.020)

    # The following command is required by BaremetalPi.jl but 
    # may be done by the MCC software
    init_gpio()
    
    gpio_set_mode(pin, :out)
    try
        gpio_set(pin)
        sleep(duration)
        gpio_clear(pin)
    catch e
        error("BaremetalPi Trigger Malfunction with error $e")
    finally
        gpio_set_mode(pin, :in)
    end
end

"""
    function readpin(pin)

Read a pin on the RPI to determine if it is true or false (on or off).
"""
function readpin(pin::Integer)
    # not tested
    init_gpio()
    
    gpio_set_mode(pin, :in)
    response = nothing
    
    try
        response = gpio_read(pin)
    catch e
        error("Could not read PIN $pin with error $e")
    end
    return response
end
