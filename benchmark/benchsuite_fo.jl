using BenchmarkTools
using Statistics
using GridTools

# Data size
const global STREAM_SIZE = 10000000 # 10 million

# Mesh definitions
const global Cell_ = Dimension{:Cell_, HORIZONTAL}
const global Cell = Cell_()

"""
    julia_broadcast_addition_setup(ARRAY_SIZE::Int64)

Setup function for the Julia broadcast addition benchmark.

# Arguments
- `ARRAY_SIZE::Int64`: The size of the arrays to be generated.

# Returns
- `a, b`: Two randomly generated arrays of integers of size `ARRAY_SIZE`.
- `data_size`: The total size of the data processed.
"""
function julia_broadcast_addition_setup(ARRAY_SIZE::Int64)
    a = rand(Int, ARRAY_SIZE)
    b = rand(Int, ARRAY_SIZE)
    data_size = sizeof(a) + sizeof(b)  # Total bytes processed
    return a, b, data_size
end

"""
    julia_broadcast_addition_operation(a, b)

Core operation for the Julia broadcast addition benchmark.

# Arguments
- `a, b`: Two arrays to be added.

# Returns
- The result of element-wise addition of `a` and `b`.
"""
function julia_broadcast_addition_operation(a, b)
    return a .+ b
end

"""
    fo_broadcast_addition_setup(FIELD_DATA_SIZE::Int64)

Setup function for the field operator broadcast addition benchmark.

# Arguments
- `FIELD_DATA_SIZE::Int64`: The size of the fields to be generated.

# Returns
- `a, b`: Two randomly generated fields of floats of size `FIELD_DATA_SIZE`.
- `out`: An output field similar to `a`.
"""
function fo_broadcast_addition_setup(FIELD_DATA_SIZE::Int64)
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
    compute_memory_bandwidth_addition(results, a, b, out)

Function to compute the memory bandwidth for the addition benchmarks.

# Arguments
- `results`: Benchmark results.
- `a, b`: The input arrays/fields used in the benchmark.
- `out`: The output array/field of the benchmark.

# Returns
- The computed memory bandwidth in GB/s.
"""
function compute_memory_bandwidth_addition(results, a, b, out)
    @assert sizeof(a.data) == sizeof(b.data) == sizeof(out.data)
    data_size = sizeof(a.data) + sizeof(b.data) + sizeof(out.data)  # Read a and b, write to out
    time_in_seconds = median(results.times) / 1e9  # Convert ns to s
    bandwidth = data_size / time_in_seconds / 1e9  # GB/s
    return bandwidth
end

# Create the benchmark suite
suite = BenchmarkGroup()

# Julia broadcast addition benchmark
a, b, data_size = julia_broadcast_addition_setup(STREAM_SIZE)
suite["julia_broadcast_addition"] = @benchmarkable $julia_broadcast_addition_operation($a, $b)

# FO broadcast addition benchmark
a, b, out = fo_broadcast_addition_setup(STREAM_SIZE)
suite["fo_broadcast_addition"] = @benchmarkable $fo_addition($a, $b, backend="embedded", out=$out)

# Run the benchmark suite
results = run(suite)

# Process the results
julia_results = results["julia_broadcast_addition"]
fo_results = results["fo_broadcast_addition"]

# Process and print the results
julia_bandwidth = compute_memory_bandwidth_addition(julia_results, a, b, a) # TODO: improve out
fo_bandwidth = compute_memory_bandwidth_addition(fo_results, a, b, out)

println("Julia broadcast addition bandwidth: $julia_bandwidth GB/s")
println("FO broadcast addition bandwidth: $fo_bandwidth GB/s")
