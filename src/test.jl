function foo(; count::Bool = false)
	foo(:ANY, count=count)	 # Match any DAQ HAT ID in hatlist()
end

function foo(id::Symbol; count::Bool = false)
	number = 5
	if count
		return number
	end
	list = foo(id, number, count=count)
	return list
end

function foo(id::Symbol, number::Integer; count::Bool = false)
	
	if number < 1
		error("Number  must be >= 1")
	end

	# number of HATS installed
	numbermax = 5

	if count
		return numbermax
	end

	if number <= numbermax
	list = Vector{String}(undef, number)
		for 
			list[i] = "$i $id"
		end
		return list	
	else
		error("Requesting $number '$id' items $numbermax available")
	end
end

