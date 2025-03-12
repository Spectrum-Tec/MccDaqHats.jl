using Gpiod: Pi, setup, OUTPUT, INPUT

p = Pi()

"""
    function trigger(pin::Int; duration::Real=5)

The pin numbers to use are the GPIO pin numbers.  Thus 23 is 
GPIO23 which is the Pi pin number 16.  The pin number reference
is available from the web or the Pi command pinout.

Note that on a fresh build of Gpiod the function setup in Gpiod.jl needs 
the following edit just befor return to work.
# pi.request[Cuint(offset)] = request  # original line
pi.request[Cuint(offset)] = isempty(pi.request) ? request : pi.request[Cuint(offset)]   # edited line
"""
function trigger(pin::Int; duration::Real = 0.020)
    try
        setup(p, pin, OUTPUT)
        write(p, pin, true)
        sleep(duration)
        write(p, pin, false)
    catch
        error("Could not trigger MCC172")
    finally
        sleep(0.001)
        setup(p, pin, INPUT)
    end
end
