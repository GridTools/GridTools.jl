using Pkg
path_to_package = joinpath(@__DIR__, "..")  # Assuming the benchmarks.jl file is in the "benchmark" directory
push!(LOAD_PATH, path_to_package)
using BenchmarkTools
using GridTools

# Mesh definitions -------------------------------------------------------------------------------------------
# const global Cell_ = Dimension{:Cell_, HORIZONTAL}
# const global K_ = Dimension{:K_, HORIZONTAL}
# const global Cell = Cell_()
# const global K = K_()
# const global Edge_ = Dimension{:Edge_, HORIZONTAL}
# const global Edge = Edge_()
# const global E2CDim_ = Dimension{:E2CDim_, LOCAL}
# const global E2CDim = E2CDim_()


# function setup_simple_connectivity()::Dict{String,Connectivity}
#     edge_to_cell_table = [
#         [1 -1];
#         [3 -1];
#         [3 -1];
#         [4 -1];
#         [5 -1];
#         [6 -1];
#         [1 6];
#         [1 2];
#         [2 3];
#         [2 4];
#         [4 5];
#         [5 6]
#     ]

#     cell_to_edge_table = [
#         [1 7 8];
#         [8 9 10];
#         [2 3 9];
#         [4 10 11];
#         [5 11 12];
#         [6 7 12]
#     ]

#     E2C_offset_provider = Connectivity(edge_to_cell_table, Cell, Edge, 2)
#     C2E_offset_provider = Connectivity(cell_to_edge_table, Edge, Cell, 3)

#     offset_provider = Dict{String,Connectivity}(
#         "E2C" => E2C_offset_provider,
#         "C2E" => C2E_offset_provider,
#         "E2CDim" => E2C_offset_provider # TODO(lorenzovarese): this is required for the embedded backend (note: python already uses E2C)
#     )

#     return offset_provider
# end

SUITE = BenchmarkGroup()

# Legacy Suite with first tests
SUITE["arith_broadcast"] = BenchmarkGroup()

a = rand(1000, 1000); b = rand(1000,1000); c = rand(1000,1000)
af = Field((Cell, K), rand(1000, 1000)); bf = Field((Cell, K), rand(1000, 1000)); cf = Field((Cell, K), rand(1000, 1000))
SUITE["arith_broadcast"]["arrays"] = @benchmarkable a .+ b .- c
SUITE["arith_broadcast"]["fields"] = @benchmarkable af .+ bf .- cf

# SUITE["field_operator"] = BenchmarkGroup()

# # Benchmark for field operator addition
# function benchmark_fo_addition()
#     a = Field(Cell, collect(1.0:15.0))
#     b = Field(Cell, collect(-1.0:-1:-15.0))
#     out = Field(Cell, zeros(Float64, 15))

#     @field_operator function fo_addition(a::Field{Tuple{Cell_},Float64}, b::Field{Tuple{Cell_},Float64})::Field{Tuple{Cell_},Float64}
#         return a .+ b
#     end

#     @benchmarkable $fo_addition($a, $b, backend="embedded", out=$out) #setup=(
#         #  a = Field(Cell, collect(1.0:15.0)); 
#         # b = Field(Cell, collect(-1.0:-1:-15.0)); 
#         # out_field = Field(Cell, zeros(Float64, 15)); 
#         # @field_operator function fo_addition(a::Field{Tuple{Cell_},Float64}, b::Field{Tuple{Cell_},Float64})::Field{Tuple{Cell_},Float64} return a .+ b end;
#         # )
# end

# SUITE["field_operator"]["addition"] = benchmark_fo_addition()

# # Benchmark for neighbor sum
# function benchmark_fo_neighbor_sum()
#     offset_provider = setup_simple_connectivity();
#     a = Field(Cell, collect(5.0:17.0) * 3);
#     E2C = FieldOffset("E2C", source=Cell, target=(Edge, E2CDim))
#     out_field = Field(Edge, zeros(Float64, 12))

#     @field_operator function fo_neighbor_sum(a::Field{Tuple{Cell_},Float64})::Field{Tuple{Edge_},Float64}
#         return neighbor_sum(a(E2C), axis=E2CDim)
#     end

#     @benchmarkable $fo_neighbor_sum($a, offset_provider=$offset_provider, out=$out_field) 
# end

# SUITE["field_operator"]["neighbor_sum"] = benchmark_fo_neighbor_sum()

run(SUITE, verbose = true, seconds = 1)
