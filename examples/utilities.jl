"""
    function getscanrate()
Get scanrate from the user
"""
function getscanrate()
    while true
        # Wait for the user to enter a response
        println("Enter scan rate [samples/s]  ")
        response = parse(Float64, readline())

        # Check for valid response
        if lowercase(response) == "y"
            return true
        elseif lowercase(response) == "n"
            return false
        else
            # Ask again.
            println("Invalid response try again.")
        end
    end
end

"""
    function wait_for_trigger(address)

Monitor the status of the specified HAT device in a loop until the
triggered status is true or the running status is false.

Args:
hat (mcc172): The mcc172 HAT device object on which the status will
be monitored.

Returns:
Nothing
"""
function wait_for_trigger(address)
# Read the status only to determine when the trigger occurs.
    is_running = true
    is_triggered = false
    while is_running && !is_triggered
        sleep(0.01)
        result_code, status_code, samples_per_channel = mcc172_a_in_scan_status(address)
        status = mcc172_status_decode(status_code)
        is_running = status.running
        is_triggered = status.triggered
    end
    return nothing
end