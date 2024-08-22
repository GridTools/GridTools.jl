# setup_benchmark_interactive.jl

# This script is intended for interactive usage during development and benchmarking sessions.
# It sets up a Julia environment with necessary packages and predefined functions for running various benchmarks.
# This allows developers to interactively profile and debug performance issues in real-time.
#
# Usage Example:
# Start Julia with the appropriate project settings and thread configuration:
# $ julia --project=. --threads 8
#
# Inside the Julia REPL, load the benchmark setup:
# julia> include("setup_benchmark_interactive.jl")
# This will load all necessary modules and display the current thread usage.
#
# To run and profile a specific operation, use:
# julia> a, out = single_field_setup(STREAM_SIZE)
# julia> @profile fo_sin(a, backend="embedded", out=out)
# This will profile the `fo_sin` operation and print profiling results.

include("../../advection/advection_setup.jl") 

using BenchmarkTools
using Statistics
using GridTools
using GridTools.ExampleMeshes.Unstructured
using GridTools.ExampleMeshes.Cartesian
using Profile
using Base.Threads

# Data size
const global STREAM_SIZE = 10_000_000

# Utils ------------------------------------------------------------------------------------------------------

# Useful for the benchmark of the field remapping operation
function create_large_connectivity(size::Int)
    edge_to_cell_table = vcat([rand(1:size, (1, 2)) for _ in 1:size]...)
    cell_to_edge_table = vcat([rand(1:size, (1, 3)) for _ in 1:size]...)

    E2C = Connectivity(edge_to_cell_table, Cell, Edge, 2)
    C2E = Connectivity(cell_to_edge_table, Edge, Cell, 3)

    Dict(
        "E2C" => E2C,
        "C2E" => C2E,
        "E2CDim" => E2C  # TODO: remove it
    )
end

"""
    compute_memory_bandwidth_single(results, a, out)::Float64

Calculates the memory bandwidth for operations that involve a single input and output field based on benchmark results.

This function measures how efficiently data is transferred to and from memory during the execution of a benchmarked operation.

# Arguments
- `results`: The benchmark results object containing timing and other performance data.
- `a`: The input field used in the benchmark.
- `out`: The output field produced by the benchmark.

# Returns
- `bandwidth`: The computed memory bandwidth in gigabytes per second (GB/s), which represents the rate at which data is read from and written to the system memory during the operation.

# Calculation Details
- `data_size`: Sum of the sizes of the input and output data in bytes.
- `time_in_seconds`: The median execution time of the benchmark, converted from nanoseconds to seconds.
- `bandwidth`: Calculated as the total data transferred divided by the time taken, expressed in GB/s.
"""
function compute_memory_bandwidth_single(results, a, out=a)::Float64
    data_size = sizeof(a.data) + sizeof(out.data)  # Read from a and write to out
    time_in_seconds = median(results.times) / 1e9  # Convert ns to s
    bandwidth = data_size / time_in_seconds / 1e9  # GB/s
    return bandwidth
end

"""
    compute_memory_bandwidth_addition(results, a, b, out)

Function to compute the memory bandwidth for the addition benchmarks.

# Arguments
- `results`: Benchmark results.
- `a, b`: The input arrays/fields used in the benchmark.
- `out`: The output array/field of the benchmark.

# Returns
- The computed memory bandwidth in GB/s.
"""
function compute_memory_bandwidth_addition(results, a, b, out)::Tuple{Float64, Int64}
    @assert sizeof(a.data) == sizeof(b.data) == sizeof(out.data)
    data_size = sizeof(a.data) + sizeof(b.data) + sizeof(out.data)  # Read a and b, write to out
    time_in_seconds = median(results.times) / 1e9  # Convert ns to s
    bandwidth = data_size / time_in_seconds / 1e9  # GB/s
    return bandwidth, data_size
end

# Operations -------------------------------------------------------------------------------------------------

"""
    single_field_setup(FIELD_DATA_SIZE::Int64)::Tuple{Field, Field}

Setup function to create a field and a similar output field for benchmarking operations that require a single input field.

# Arguments
- `FIELD_DATA_SIZE::Int64`: The size of the field to be generated.

# Returns
- `a`: A randomly generated field of floats of size `FIELD_DATA_SIZE`.
- `out`: An output field similar to `a`, used for storing operation results.
"""
function single_field_setup(FIELD_DATA_SIZE::Int64)::Tuple{Field, Field}
    a = Field(Cell, rand(Float64, FIELD_DATA_SIZE))
    out = GridTools.similar_field(a)
    return a, out
end

"""
    array_broadcast_addition_setup(ARRAY_SIZE::Int64)

Setup function for the Julia broadcast addition benchmark.

# Arguments
- `ARRAY_SIZE::Int64`: The size of the arrays to be generated.

# Returns
- `a, b`: Two randomly generated arrays of integers of size `ARRAY_SIZE`.
- `data_size`: The total size of the data processed.
"""
function array_broadcast_addition_setup(ARRAY_SIZE::Int64)::Tuple{Array{Float64,1}, Array{Float64,1}, Int64}
    a = rand(Float64, ARRAY_SIZE)
    b = rand(Float64, ARRAY_SIZE)
    data_size = sizeof(a) + sizeof(b)  # Total bytes processed
    return a, b, data_size
end

"""
    broadcast_addition_array(a::Array{Float64}, b::Array{Float64})

Core operation for the Julia broadcast addition benchmark.

# Arguments
- `a, b`: Two arrays to be added.

# Returns
- The result of element-wise addition of `a` and `b`.
"""
function broadcast_addition_array(a::Array{Float64}, b::Array{Float64})::Array{Float64,1}
    return a .+ b
end

"""
    broadcast_addition(a::Field, b::Field)

Core operation for the broadcast addition of two Field benchmark.
Useful to asses and track possible overhead on fields.

# Arguments
- `a, b`: Two field to be added.

# Returns
- The result of element-wise addition of the data of the fields `a` and `b`.
"""
function broadcast_addition_fields(a::Field, b::Field)::Field
    return a .+ b
end

"""
    fields_broadcast_addition_setup(FIELD_DATA_SIZE::Int64)

Setup function for the field operator broadcast addition benchmark.

# Arguments
- `FIELD_DATA_SIZE::Int64`: The size of the fields to be generated.

# Returns
- `a, b`: Two randomly generated fields of floats of size `FIELD_DATA_SIZE`.
- `out`: An output field similar to `a`.
"""
function fields_broadcast_addition_setup(FIELD_DATA_SIZE::Int64)::Tuple{Field, Field, Field}
    a = Field(Cell, rand(Float64, FIELD_DATA_SIZE))
    b = Field(Cell, rand(Float64, FIELD_DATA_SIZE))
    out = GridTools.similar_field(a)
    return a, b, out
end

"""
    fo_addition(a::Field{Tuple{Cell_},Float64}, b::Field{Tuple{Cell_},Float64})::Field{Tuple{Cell_},Float64}

Core operation for the field operator broadcast addition benchmark.

# Arguments
- `a, b`: Two fields to be added.

# Returns
- The result of element-wise addition of `a` and `b`.
"""
@field_operator function fo_addition(a::Field{Tuple{Cell_},Float64}, b::Field{Tuple{Cell_},Float64})::Field{Tuple{Cell_},Float64}
    return a .+ b
end

"""
    sin_without_fo(a::Field{Tuple{Cell_},Float64})::Field{Tuple{Cell_},Float64}

Applies the sine function element-wise to the data of a field without using a field operator.

# Arguments
- `a`: Input field containing Float64 data.

# Returns
- A new field where each element is the sine of the corresponding element in the input field `a`.
"""
function sin_without_fo(a::Field{Tuple{Cell_},Float64})::Field{Tuple{Cell_},Float64}
    return sin.(a)
end

"""
    cos_without_fo(a::Field{Tuple{Cell_},Float64})::Field{Tuple{Cell_},Float64}

Applies the cosine function element-wise to the data of a field without using a field operator.

# Arguments
- `a`: Input field containing Float64 data.

# Returns
- A new field where each element is the cosine of the corresponding element in the input field `a`.
"""
function cos_without_fo(a::Field{Tuple{Cell_},Float64})::Field{Tuple{Cell_},Float64}
    return cos.(a)
end

"""
    fo_sin(a::Field{Tuple{Cell_},Float64})::Field{Tuple{Cell_},Float64}

Field operator that applies the sine function element-wise to the data of a field.

# Arguments
- `a`: Input field containing Float64 data.

# Returns
- A new field where each element is the sine of the corresponding element in the input field `a`.
"""
@field_operator function fo_sin(a::Field{Tuple{Cell_},Float64})::Field{Tuple{Cell_},Float64}
    return sin.(a)
end

"""
    fo_cos(a::Field{Tuple{Cell_},Float64})::Field{Tuple{Cell_},Float64}

Field operator that applies the cosine function element-wise to the data of a field.

# Arguments
- `a`: Input field containing Float64 data.

# Returns
- A new field where each element is the cosine of the corresponding element in the input field `a`.
"""
@field_operator function fo_cos(a::Field{Tuple{Cell_},Float64})::Field{Tuple{Cell_},Float64}
    return cos.(a)
end

"""
    fo_remapping(a::Field{Tuple{Cell_},Float64})::Field{Tuple{Edge_},Float64}

Field operator that performs remapping from cell-based data to edge-based data.

This operator utilizes a connectivity table (`E2C`) to map the values from cells to edges, implying a transformation from the cell-centered field to an edge-centered field based on predefined relationships in the connectivity table.

# Arguments
- `a`: Input field containing Float64 data structured around cells.

# Returns
- A new field where each element represents data remapped from cells to edges, structured as specified by the edge-to-cell connectivity.
"""
@field_operator function fo_remapping(a::Field{Tuple{Cell_},Float64})::Field{Tuple{Edge_},Float64}
    return a(E2C[1])
end

"""
    fo_neighbor_sum(a::Field{Tuple{Cell_},Float64})::Field{Tuple{Edge_},Float64}

Field operator that computes the sum of neighboring cell values for each edge. This function leverages the connectivity table (`E2C`), which defines the relationship between edges and cells, to sum the values of cells that are connected to each edge.

The summation is performed across the dimension specified by `E2CDim`, ensuring that each edge aggregates values from its associated cells correctly.

# Arguments
- `a`: Input field containing Float64 data, where each cell contains a numerical value.

# Returns
- A new field where each edge holds the summed value of its neighboring cells, based on the edge-to-cell connectivity defined in `E2C`.
"""
@field_operator function fo_neighbor_sum(a::Field{Tuple{Cell_},Float64})::Field{Tuple{Edge_},Float64}
    return neighbor_sum(a(E2C), axis=E2CDim)
end

# Start ------------------------------------------------------------------------------------------------------
println("Current number of threads: ", Threads.nthreads())
println("The environment is ready\n")
Profile.clear()
