using Clang.Generators
using Clang.LibClang.Clang_jll

#include("/usr/local/include/daqhats/daqhats.h")

cd(@__DIR__)

header_dir = "/usr/local/include/daqhats"

header_files = [file for file in readdir(header_dir, join=true) if endswith(file, ".h")]

for header in header_files
    num = filter(isdigit, splitpath(header)[end])
    options = load_options(joinpath(@__DIR__, "generator$num.toml"))

    # add compiler options
    args = get_default_args()
    push!(args, "-I$header_dir")


    #headers = [joinpath(header_dir, header) for header in readdir(header_dir) if endswith(header, ".h")]

    ctx = create_context(header, args, options)

    build!(ctx)
end
