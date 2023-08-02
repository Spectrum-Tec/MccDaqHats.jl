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

