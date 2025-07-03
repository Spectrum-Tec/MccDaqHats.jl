using PiGPIO

#= 
Its downside is that it requires root privileges.
Before first use, the daemon must be launched from the shell
with sudo privileges.  This is only done once per Linux session

set up the daemon
# install pigpiod
sudo apt-get install pigpiod
# enable pigpiod via system D
sudo systemctl enable pigpiod
# start pigpiod now
sudo systemctl start pigpiod


The daemon does not work with the PI 5 as of 6 mar 2025
=#

function __init__()
try
    t = `sudo pigpiod`
    run(t)
catch e
    error("Initializing daemon with error $e")
end
end

"""
    function trigger(pin::Integer; duration::Number=0.050)

The pin numbers to use are the GPIO pin numbers.  Thus 23 is 
GPIO23 which is the Pi pin number 16.  The pin number reference
is available from the web or the Pi command pinout.

Alternative Packages to try:
    https://github.com/notinaboat/PiGPIOMEM.jl/blob/master/src/PiGPIOMEM.jl
    PiGPIO.jl
    etc.
"""
function trigger(pin::Integer; duration::Number = 0.050)
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
