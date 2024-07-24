using Pkg
path_to_package = joinpath(@__DIR__, "..")  # Assuming the benchmarks.jl file is in the "benchmark" directory
push!(LOAD_PATH, path_to_package)
using BenchmarkTools
using GridTools

# Mesh definitions -------------------------------------------------------------------------------------------
const global Cell_ = Dimension{:Cell_, HORIZONTAL}
const global K_ = Dimension{:K_, HORIZONTAL}
const global Cell = Cell_()
const global K = K_()

SUITE = BenchmarkGroup()

SUITE["arith_broadcast"] = BenchmarkGroup()

a = rand(1000, 1000); b = rand(1000,1000); c = rand(1000,1000)
af = Field((Cell, K), rand(1000, 1000)); bf = Field((Cell, K), rand(1000, 1000)); cf = Field((Cell, K), rand(1000, 1000))
SUITE["arith_broadcast"]["arrays"] = @benchmarkable a .+ b .- c
SUITE["arith_broadcast"]["fields"] = @benchmarkable af .+ bf .- cf

# Benchmark for field operator addition

# function benchmark_fo_addition()
#     a = Field(Cell, collect(1.0:15.0))
#     b = Field(Cell, collect(-1.0:-1:-15.0))
#     out = Field(Cell, zeros(Float64, 15))

#     @field_operator function fo_addition(a::Field{Tuple{Cell_},Float64}, b::Field{Tuple{Cell_},Float64})::Field{Tuple{Cell_},Float64}
#         return a .+ b
#     end

#     @benchmarkable fo_addition(a, b, backend="embedded", out=out)
# end

# SUITE["field_operator"]["addition"] = benchmark_fo_addition()

run(SUITE, verbose = true, seconds = 1)
