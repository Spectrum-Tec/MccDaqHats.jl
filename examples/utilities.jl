using Arrow
using Dates
using InspectDR
using Plots
using MAT

abstract type Header end

const NodeOrientation = Dict("x" => 1, "y" => 2, "z" => 3, "-x" => -1, "-y" => -2, "-z" => -3)

struct Header151Model <: Header  # slightly different from Matlab but should not matter
	dsType::Integer
	modelName::String
	description::String
	sourceProgram::String			# program which created data
	dateTimeCreated::String
	applicationVersion::String
	writingProgram::String
	lastSaveDateTime::String
end

struct Header164Unit <: Header  # will only use SI units here
	dsType::Integer
	unitsCode::Integer
	unitsDescription::String
	tempMode::Integer
	facLength::AbstractFloat
	facForce::AbstractFloat
	facTemp::AbstractFloat
	facTempOffset::AbstractFloat
end

struct Header58 <: Header  # only use time history here
	d1::String
	d2::String
	Date::String
	d4::String
	d5::String
	functionType::Integer
	resEntName::String		# max length of 10 for UFF file
	resNode::Integer		# max length of 10 for UFF file
	resDir::Integer			# 1=>x, 2=>y, 3=>z, -1=>-x  ....
	ordDataType::Integer
	spacingType::Integer
	xmin::AbstractFloat
	dx::AbstractFloat
	numpt::Integer
	abscDataChar::Integer
	abscUnitsLabel::String
	ordDataChar::Integer
	dstype::Integer
end


"""
    function getscanrate()
Get scanrate from the  not used here
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
	td2matlab(datafile, matlabfile) -> nothing
Convert the time data file to matlab file for winder vibration analysis.
	
This can then be analyzed with ST Matlab programs.
"""
datafile = "C:\\data\\st\\analyzer\\KingseyFalls\\test data\\ArrowData\\AcquisitionSet_1_2024-10-01T223031.arrow"
datafile = "C:\\data\\st\\analyzer\\PrinceGeorge\\2024Dec\\ReelHardness\\pgreel.arrow"
function td2matlab(datafile::String; matlabfile::String = (splitext(datafile)[1] * ".mat"))
    data = Arrow.Table(datafile)
    # fieldnames(typeof(data)); getfield(data, :names); etc
    nc = length(getfield(data, :names))
    nr=length(data[1])
    columns = 1:nc
    datadict = Arrow.getmetadata(data)
    #colmetadata = Arrow.getmetadata(data.Column1)  # but in Arrow.jl returns nothing till issue resolved
    Δt = 1 / parse(Float64, datadict["measfs"])
    time = range(0, step=Δt, length=nr)
    # plot(time, [data[1] data[2]])
    timedata = Matrix{Float32}(undef, nr, nc)
    for c in columns
        timedata[1:nr, c] = data[c]
    end

    datetimecreated = datadict["starttime"]   # make string for matlab compatibility
    dateNow = string(now())
 
    i = 1
    ufftime = Vector{Header58}(undef, i) # nuumber of channels
    for i = 1:1  # this needs to be extended for generality
        starttime = datadict["starttime"]
        id = datadict["chan" * string(i) * "ID"]
        #node = parse(Int, datadict["chan" * string(i) * "node"])
        node = 1
        eu = datadict["chan" * string(i) * "eu"]
        dx = Δt
        orient = 0
        numpt = nr
        ordchar = 12 # guessing for now, not used in complex modulus program
        ufftime[i] = Header58("NONE", "NONE", starttime, "NONE", "NONE", 1, id, node, orient, 4, 1, 0, dx, numpt, 17, eu, ordchar, 58)
    end

    starttime = DateTime(datadict["starttime"], dateformat"yyyy-mm-ddTHH:MM:SS.sss")
    uff151 = Header151Model(151, "Time History data from $(datafile)",
        "Data for Matlab Data Analysis from $datafile", "Pi Arrow",
        datetimecreated, "0.01", "td2matlab.jl", dateNow)
    @debug " Start 164"
    uff164 = Header164Unit(164, 1, "SI: Meter (Newton)", 2, 1.0, 1.0, 1.0, 273.15)

    matwrite(matlabfile, Dict(
            "UFF151" => uff151,
            "UFF164" => uff164,
            "UFFTime" => ufftime,
            "Time" => timedata);
        compress=true)

      return nothing
end

"""
    function plotarrow(filename::String)

Plot an arrow file collected by mcc172acquire
"""
function plotarrow(filename::String; channels=1)
    inspectdr()
    data = Arrow.Table(filename)
    datadict = Arrow.getmetadata(data)
    colmetadata = Arrow.getmetadata(data.Column1)  # but in Arrow.jl returns nothing till issue resolved
    Δt = 1/parse(Float64, datadict["measfs"])
    nr=length(data[1])
    acqtime = range(0, step=Δt, length=nr)
    # plot(acqtime, [data[1] data[2]])
    # plot(acqtime, data[1:2])  # Cannot index into Arrow this way
    
    plotdata = Matrix{Float32}(undef, nr, length(channels))
    for (i, c) in enumerate(channels)
        plotdata[1:nr, i] = data[c]
    end
    plot(acqtime, plotdata)
end

#=
begin
    fh5 = h5open(filename, "r")
    data = read_dataset(fh5, "data")
    close(fh5)
    Δt = 1/parse(Float64, datadict["measfs"])
   d
=#
