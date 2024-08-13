
using BenchmarkTools
using Statistics
using GridTools  

const N = 1_000_000
const DIM_SIZE = sqrt(N) |> floor |> Int

include("../test/mesh_definitions.jl")

function create_large_connectivity(size::Int)
    edge_to_cell_table = hcat([rand(1:size, 2) for _ in 1:size]...)
    cell_to_edge_table = hcat([rand(1:size, 3) for _ in 1:size]...)

    E2C = Connectivity(edge_to_cell_table, Cell, Edge, 2)
    C2E = Connectivity(cell_to_edge_table, Edge, Cell, 3)

    Dict(
        "E2C" => E2C,
        "C2E" => C2E,
        "E2CDim" => E2C  # Using the same for simplicity # TODO: to be removed
    )
end

offset_provider = create_large_connectivity(DIM_SIZE)

a = Field(Cell, collect(1.0:N))
out_field = GridTools.similar_field(a)

@field_operator function fo_neighbor_sum(a::Field{Tuple{Cell_},Float64})::Field{Tuple{Edge_},Float64}
    return neighbor_sum(a(E2C), axis=E2CDim)
end

# Benchmark the field operation
fo_benchmark = @benchmarkable $fo_neighbor_sum($a, offset_provider=$offset_provider, backend="embedded", out=$out_field)

# Run the benchmark
results = run(fo_benchmark)

# Memory bandwidth calculation
time_in_seconds = median(results.times) / 1e9  # convert ns to s
data_size = sizeof(a.data) + sizeof(out_field.data)  # total bytes read and written
bandwidth = data_size / time_in_seconds / 1e9  # GB/s

# Output results
println("Time taken: ", median(results.times) / 1e6, " ms")
println("Memory bandwidth: ", bandwidth, " GB/s")
