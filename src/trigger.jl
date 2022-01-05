using BaremetalPi

"""
    function trigger(pin::Int)

The pin numbers to use are the GPIO pin numbers.  Thus 23 is 
GPIO23 which is the Pi pin number 16.  The pin number reference
is available from the web or the Pi command pinout.

Alternative Packages to try:
    https://github.com/notinaboat/PiGPIOMEM.jl/blob/master/src/PiGPIOMEM.jl
    PiGPIO.jl
    etc.
"""
function trigger(pin::Int; duration::Real = 0.050)

    # The following command is required by BaremetalPi.jl but 
    # may be done by the MCC software
    init_gpio()
    
    gpio_set_mode(pin, :out)
    try
        gpio_set(pin)
        sleep(duration)
        gpio_clear(pin)
    finally
        gpio_set_mode(pin, :in)
    end
end


#=
# Using the PiGPIO package.  Its downside is that it requires 
# root privileges.
using PiGPIO

"""
    function trigger(pin::Int)

Before first use, the daemon must be launched from the shell
with sudo privileges.  This is only done once per Linux session

The pin numbers to use are the GPIO pin numbers.  Thus 23 is 
GPIO23 which is the Pi pin number 16.  The pin number reference
is available from the web or the Pi command pinout.

    try
        t = `sudo pigpiod`
        run(t)
    end
"""
function trigger(pin::Int)
    p = Pi()
    set_mode(p, pin, PiGPIO.OUTPUT)
    try
        PiGPIO.write(p, pin, PiGPIO.ON)
        sleep(5)
        PiGPIO.write(p, pin, PiGPIO.OFF)
    finally
        set_mode(p, pin, PiGPIO.INPUT)
    end
end
=#