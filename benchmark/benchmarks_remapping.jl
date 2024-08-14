using BenchmarkTools
using Statistics
using GridTools  

const N = 10_000_000 |> floor |> Int # Adjust as needed (10 millions is the SLURM test size)

include("../test/mesh_definitions.jl")  # Ensure all necessary mesh and dimension definitions are loaded

# Unstructured Mesh ------------------------------------------------------------------------------------------

function create_large_connectivity(size::Int)
    edge_to_cell_table = hcat([rand(1:size, 2) for _ in 1:size]...)
    cell_to_edge_table = hcat([rand(1:size, 3) for _ in 1:size]...)

    E2C = Connectivity(edge_to_cell_table, Cell, Edge, 2)
    C2E = Connectivity(cell_to_edge_table, Edge, Cell, 3)

    Dict(
        "E2C" => E2C,
        "C2E" => C2E,
        "E2CDim" => E2C  # TODO: remove it
    )
end

offset_provider = create_large_connectivity(N)

a = Field(Cell, collect(1.0:N))
out_field = GridTools.similar_field(a)

@field_operator function fo_remapping(a::Field{Tuple{Cell_},Float64})::Field{Tuple{Edge_},Float64}
    return a(E2C[1])
end

# Benchmark the field remapping operation
remapping_benchmark = @benchmarkable $fo_remapping($a, offset_provider=$offset_provider, backend="embedded", out=$out_field)

# Run the benchmark
results = run(remapping_benchmark)

# Memory bandwidth calculation
unstr_time_in_seconds = median(results.times) / 1e9  # convert ns to s
unstr_data_size = sizeof(a.data) + sizeof(out_field.data)  # total bytes read and written
unstr_bandwidth = unstr_data_size / unstr_time_in_seconds / 1e9  # GB/s

# Output results
println("Time taken: ", median(results.times) / 1e6, " ms")
println("Memory bandwidth for Unstructured Mesh Remapping: ", unstr_bandwidth, " GB/s")

# Cartesian Mesh ---------------------------------------------------------------------------------------------

# Cartesian Offset Field Operator
@field_operator function fo_cartesian_offset(inp::Field{Tuple{K_},Float64})::Field{Tuple{K_},Float64}
    return inp(Koff[1])
end

# Create and benchmark the Cartesian offset operation
a = Field(K, collect(1.0:N))
out_field = Field(K, zeros(Float64, N-1))
cartesian_offset_provider = Dict("Koff" => K)

cartesian_benchmark = @benchmarkable $fo_cartesian_offset($a, backend="embedded", out=$out_field, offset_provider=$cartesian_offset_provider)
cartesian_results = run(cartesian_benchmark)

# Memory bandwidth calculation
cartesian_time_in_seconds = median(cartesian_results.times) / 1e9  # convert ns to s
cartesian_data_size = sizeof(a.data) + sizeof(out_field.data)  # total bytes read and written
cartesian_bandwidth = cartesian_data_size / cartesian_time_in_seconds / 1e9  # GB/s

# Output results
println("Time taken for Cartesian Mesh Offset: ", median(cartesian_results.times) / 1e6, " ms")
println("Memory bandwidth for Cartesian Mesh Offset: ", cartesian_bandwidth, " GB/s")
