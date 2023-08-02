The example files have been ported from the python and C examples. 
They may not work perfectly and the try catch finally may not be 
optimum.  They do show how the Julia code can work.

The continuous_scan() is working useful code.  It collects data from 
multiple MCC172 HATS, using a GPIO pin to trigger the acquisition.
This makes the program self contained without the need for an external
trigger since it uses the internal trigger.  
