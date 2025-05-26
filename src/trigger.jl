using Gpiod: Pi, setup, OUTPUT, INPUTS

#= 
Used the dev version of this package as it has the libgpiod.so file contained within it.
See issue for Gpio.jl on github for specifics
=#


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
function trigger(pin::Int; duration::Real = 0.050)
    p = Pi()
    setup(p, pin, OUTPUT)
    try
        write(p, pin, true)
        sleep(duration)
        write(p, pin, false)
    catch
        error("")
    # finally
	# sleep(0.1)
        # setup(p, pin, INPUT)
    end
end
