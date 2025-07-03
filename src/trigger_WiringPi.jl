#=
According to documentation julia needs root privileges or we need 
to fiddle with permissions.  I have not done either and it seems to 
work.
=#

using WiringPi

"""
    function trigger(pin::Integer; duration::Number=0.050)

The pin numbers to use are the GPIO pin numbers.  Thus 23 is 
GPIO23 which is the Pi pin number 16.  The pin number reference
is available from the web or the Pi command pinout.
"""
function trigger(pin::Integer; duration::Number = 0.020)
    try
        wiringPiSetupGpio()
        pinMode(pin, OUTPUT)
        digitalWrite(pin, true)
        sleep(duration)
        digitalWrite(pin, false)
    catch e
        error("WiringPi Trigger Malfunction with error $e")
    end
end

"""
    function readpin(pin::Integer)

Read a pin on the RPI to determine if it is true or false (on or off).
"""
function readpin(pin::Integer)
    #try
        wiringPiSetupGpio()
        pinMode(pin, INPUT)
        response = digitalRead(pin)
    #catch e
        #error("Could not read PIN $pin with error $e")
    #end
    return response
end
