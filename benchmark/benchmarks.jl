using BenchmarkTools
using Statistics
using GridTools

# Data size
const global STREAM_SIZE = 10000000 # 10 million

# Mesh definitions
const global Cell_ = Dimension{:Cell_, HORIZONTAL}
const global Cell = Cell_()

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
    compute_memory_bandwidth_addition(results, a, b, out)

Function to compute the memory bandwidth for the addition benchmarks.

# Arguments
- `results`: Benchmark results.
- `a, b`: The input arrays/fields used in the benchmark.
- `out`: The output array/field of the benchmark.

# Returns
- The computed memory bandwidth in GB/s.
"""
function compute_memory_bandwidth_addition(results, a, b, out)::Float64
    @assert sizeof(a.data) == sizeof(b.data) == sizeof(out.data)
    data_size = sizeof(a.data) + sizeof(b.data) + sizeof(out.data)  # Read a and b, write to out
    time_in_seconds = median(results.times) / 1e9  # Convert ns to s
    bandwidth = data_size / time_in_seconds / 1e9  # GB/s
    return bandwidth
end

# Create the benchmark suite
suite = BenchmarkGroup()

# Define the main groups
suite["addition"] = BenchmarkGroup()

# Julia broadcast addition benchmark
a, b, data_size = array_broadcast_addition_setup(STREAM_SIZE)
suite["addition"]["array_broadcast_addition"] = @benchmarkable $broadcast_addition_array($a, $b)

# Field broadcast addition benchmark
a, b, out = fields_broadcast_addition_setup(STREAM_SIZE)
suite["addition"]["fields_broadcast_addition"] = @benchmarkable $broadcast_addition_fields($a, $b)

# Field Operator broadcast addition benchmark
a, b, out = fields_broadcast_addition_setup(STREAM_SIZE)
suite["addition"]["field_op_broadcast_addition"] = @benchmarkable $fo_addition($a, $b, backend="embedded", out=$out)

# Run the benchmark suite
results = run(suite)

# Process the results
array_results = results["addition"]["array_broadcast_addition"]
fields_results = results["addition"]["fields_broadcast_addition"]
fo_results = results["addition"]["field_op_broadcast_addition"]

# Process and print the results
array_bandwidth = compute_memory_bandwidth_addition(array_results, a, b, a) # Out is a temporary array with size a
fields_bandwidth = compute_memory_bandwidth_addition(fields_results, a, b, a) # Out is a temporary array with size a
fo_bandwidth = compute_memory_bandwidth_addition(fo_results, a, b, out)

println("Array broadcast addition bandwidth:\t\t$array_bandwidth GB/s")
println("Fields data broadcast addition bandwidth:\t$fields_bandwidth GB/s")
println("Field Operator broadcast addition bandwidth:\t$fo_bandwidth GB/s")
