# Example of real time plot to use for strip chart recording


using InspectDR
using Colors

function getmeasdata(t, φ)
	sig = Matrix{Float64}(undef, length(t), 3)
	sig[:,1] = sin.(t .+ φ)
	sig[:,2] = cos.(t .+ φ)
	sig[:,3] = sin.(t .+ φ) .+ cos.(t .+ φ)
	return sig
end

#Build general structure of animation plot
function buildanimplot()
	NPOINTS = 50_000 #1000
	NCYCLES = 2 #To display
	#RED = RGB24(1, 0, 0)
	#GREEN = RGB24(0, 1, 0)
	#BLUE = RGB24(0, 0, 1)
	color = [
        RGB24(1, 0, 0),  # red
        RGB24(0, 1, 0),  # green
        RGB24(0, 0, 1),  # blue
        RGB24(1, 0.2, 1)] # magenta
	nchan = 3

	#collect: InspectDR does not take AbstractArray:
	t = collect(range(0, stop=NCYCLES*2pi, length=NPOINTS))
	sig = getmeasdata(t, 0)

	#Using Plot2D simplified "template" constructor:
	p = InspectDR.Plot2D(:lin, fill(:lin, nchan),
		title = "Measured Data", xlabel = "time (s)",
		ylabels = fill("Amplitude (V)", nchan))
	p.layout[:enable_legend] = true

	wfrm = Vector{InspectDR.Waveform{InspectDR.IDataset}}(undef, nchan)
	for c in 1:nchan
		wfrm[c] = add(p, t, sig[:,c], id="Signal $c", strip=c)
		wfrm[c].line = line(color=color[c], width=2)
	end

	gplot = display(InspectDR.GtkDisplay(), p)
	return (gplot, t, wfrm)
end

#Update animated plot in "real time":
function testanimplot()
	DURATION = 5 #sec
	NSTEPS = 100
	RADPERSEC = 2pi
	tstep = DURATION/NSTEPS
	ϕstep = RADPERSEC * tstep

	(gplot, t, wfrm) = buildanimplot()

	@time begin #Curious to see how long it actually takes
		for ϕ in range(0, step=ϕstep, length=NSTEPS)
			amp = (ϕ + NSTEPS)/NSTEPS
			#sleep(DURATION/NSTEPS)
			sig = getmeasdata(t, ϕ)
			nchan = size(sig,2)
			for c in 1:nchan
				wfrm[c].ds.y = sig[:,c] .* amp
			end
			InspectDR.refresh(gplot)
		end
	end
	return gplot
end

# gplot = testanimplot()  # Execute this command
