The *.toml files are used by Clang.jl, read the Clang documentation.

The output files are the .jl files.  These are used as the basis for
the actual .jl files used to access the DAQHATS.  This has been done 
for mcc172.jl which is working.  The remaining .jl files still need this 
editing. Clang cannot distinguish between inputs and outputs from the 
C header files so this needs to be manually done.