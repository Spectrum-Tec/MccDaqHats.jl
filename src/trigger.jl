using Gpiod: Pi, setup, OUTPUT, INPUTS

const pi = Pi()

#= 
Used the dev version of this package as it has the libgpiod.so file contained within it.
See issue for Gpio.jl on github for specifics
=#


"""
    function trigger(pin::Int; duration::Real=0.050)

The pin numbers to use are the GPIO pin numbers.  Thus 23 is 
GPIO23 which is the Pi pin number 16.  The pin number reference
is available from the web or the Pi command pinout.

Note that on a fresh build of Gpiod the function setup in Gpiod.jl needs 
the following edit just before return to work.  I think this note is now 
old information and no longer required.
# pi.request[Cuint(offset)] = request  # original line
pi.request[Cuint(offset)] = isempty(pi.request) ? request : pi.request[Cuint(offset)]   # edited line
"""
function trigger(pin::Integer; duration::Real = 0.020)
    try
        write(pi, pin, true)
        sleep(duration)
        write(pi, pin, false)
    catch
        error("")
    # finally
	# sleep(0.1)
        # setup(pi, pin, INPUT)
    end
end

"""
    function readpin(pin)

Read a pin on the RPI to determine if it is true or false (on or off).
"""
function readpin(pin::Integer)
    try
        setup(pi, pin, INPUT)
        response = read(pi, pin)
    catch
        error("Could not read PIN $pin")
    end
    return response
end
