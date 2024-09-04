using BenchmarkTools
using CUDA
using GridTools
using GridTools.ExampleMeshes.Unstructured

# Data size
const global STREAM_SIZE = 10_000_000

"""
    compute_memory_bandwidth_addition(results, a, b, out)::Tuple{Float64, Int64}

Function to compute the memory bandwidth for the addition benchmarks.

# Arguments
- `results`: The benchmark results containing timing information (`times`).
- `a, b`: The input fields or arrays used in the benchmark.
- `out`: The output field or array used in the benchmark.

# Returns
- A tuple `(bandwidth, data_size)` where:
    - `bandwidth`: The memory bandwidth in gigabytes per second (GB/s).
    - `data_size`: The total size of the data processed in bytes.
"""
function compute_memory_bandwidth_addition(results, a, b, out)::Tuple{Float64, Int64}
    # Ensure the sizes of the data fields are consistent
    @assert sizeof(a.data) == sizeof(b.data) == sizeof(out.data)

    # Calculate the total size of data read and written in bytes
    # Read from `a` and `b`, and write to `out`
    data_size = sizeof(a.data) + sizeof(b.data) + sizeof(out.data)

    # Compute the median execution time from benchmark results in seconds (convert from nanoseconds)
    time_in_seconds = median(results.times) / 1e9

    # Calculate memory bandwidth in GB/s
    bandwidth = data_size / time_in_seconds / 1e9

    return bandwidth, data_size
end

# GPU Setup Functions -----------------------------------------------------------------------------------------

"""
    gpu_broadcast_addition_setup(ARRAY_SIZE::Int64)

Setup function for the GPU broadcast addition benchmark using CuArray.

# Arguments
- `ARRAY_SIZE::Int64`: The size of the GPU arrays to be generated.

# Returns
- `a, b`: Two CuArray GPU arrays of size `ARRAY_SIZE`.
- `data_size`: The total size of the data processed.
"""
function gpu_broadcast_addition_setup(ARRAY_SIZE::Int64)::Tuple{CuArray{Float64,1}, CuArray{Float64,1}, Int64}
    a_gpu = CuArray(rand(Float64, ARRAY_SIZE))
    b_gpu = CuArray(rand(Float64, ARRAY_SIZE))
    data_size = sizeof(a_gpu) + sizeof(b_gpu)  # Total bytes processed
    return a_gpu, b_gpu, data_size
end

"""
    gpu_fields_broadcast_addition_setup(FIELD_DATA_SIZE::Int64)

Setup function for the GPU field broadcast addition benchmark using CuArray.

# Arguments
- `FIELD_DATA_SIZE::Int64`: The size of the fields to be generated.

# Returns
- `a, b`: Two randomly generated fields of CuArray floats of size `FIELD_DATA_SIZE`.
- `out`: An output field similar to `a`, used for storing operation results.
"""
function gpu_fields_broadcast_addition_setup(FIELD_DATA_SIZE::Int64)::Tuple{Field, Field, Field}
    a_gpu = Field(Cell, CuArray(rand(Float64, FIELD_DATA_SIZE)))
    b_gpu = Field(Cell, CuArray(rand(Float64, FIELD_DATA_SIZE)))
    out_gpu = GridTools.similar_field(a_gpu)
    return a_gpu, b_gpu, out_gpu
end

# CuArray only
function gpu_broadcast_addition_array(a::CuArray{Float64}, b::CuArray{Float64})::CuArray{Float64}
    return a .+ b
end

# Fields and broadcasting
function gpu_broadcast_addition_fields(a::Field{Tuple{Cell_},Float64}, b::Field{Tuple{Cell_},Float64})::Field{Tuple{Cell_},Float64}
    return a .+ b
end

function arr_add_wrapper(a, b)
    CUDA.@sync begin
        return gpu_broadcast_addition_array(a,b)
    end
end

function field_add_wrapper(a, b)
    CUDA.@sync begin
        return gpu_broadcast_addition_fields(a,b)
    end
end

@field_operator function gpu_fo_addition_with_wrapper(a::Field{Tuple{Cell_},Float64}, b::Field{Tuple{Cell_},Float64})::Field{Tuple{Cell_},Float64}
    CUDA.@sync begin
        return a .+ b
    end
end

# Benchmarks -------------------------------------------------------------------------------------------------

# Create the GPU benchmark SUITE
SUITE_GPU = BenchmarkGroup()

# Define the GPU addition benchmarks
SUITE_GPU["gpu_addition"] = BenchmarkGroup()

# GPU broadcast addition benchmark
a_gpu, b_gpu, data_size_gpu = gpu_broadcast_addition_setup(STREAM_SIZE)
SUITE_GPU["gpu_addition"]["gpu_array_broadcast_addition"] = @benchmarkable $arr_add_wrapper($a_gpu, $b_gpu)

# GPU Field broadcast addition benchmark # TODO(lorenzovarese): fix the CUDA.@sync, results are unrealistic
a_gpu, b_gpu, out_gpu = gpu_fields_broadcast_addition_setup(STREAM_SIZE)
SUITE_GPU["gpu_addition"]["gpu_fields_broadcast_addition"] = @benchmarkable $field_add_wrapper($a_gpu, $b_gpu)

# GPU Field Operator broadcast addition benchmark # TODO(lorenzovarese): fix the CUDA.@sync, results are unrealistic
a_gpu, b_gpu, out_gpu = gpu_fields_broadcast_addition_setup(STREAM_SIZE)
SUITE_GPU["gpu_addition"]["gpu_field_op_broadcast_addition"] = @benchmarkable $gpu_fo_addition($a_gpu, $b_gpu, backend="embedded", out=$out_gpu)

# Running the GPU benchmark SUITE
println("Running the GPU benchmark SUITE...")
gpu_results = run(SUITE_GPU)

# Process and print the GPU results
gpu_array_results = gpu_results["gpu_addition"]["gpu_array_broadcast_addition"]
gpu_fields_results = gpu_results["gpu_addition"]["gpu_fields_broadcast_addition"]
gpu_fo_results = gpu_results["gpu_addition"]["gpu_field_op_broadcast_addition"]

# Compute memory bandwidth for GPU benchmarks
gpu_array_bandwidth, data_size_arr_gpu = compute_memory_bandwidth_addition(gpu_array_results, a_gpu, b_gpu, a_gpu)
gpu_fields_bandwidth, data_size_fields_gpu = compute_memory_bandwidth_addition(gpu_fields_results, a_gpu, b_gpu, a_gpu)
gpu_fo_bandwidth, data_size_fo_gpu = compute_memory_bandwidth_addition(gpu_fo_results, a_gpu, b_gpu, out_gpu)

# Function to convert nanoseconds to milliseconds for clearer output
ns_to_ms(time_ns) = time_ns / 1e6

# Output results for GPU benchmarks
println("GPU Array broadcast addition:")
println("\tData size: $data_size_arr_gpu")
println("\tBandwidth: $gpu_array_bandwidth GB/s")
println("\tTime taken: $(ns_to_ms(median(gpu_array_results.times))) ms\n")

println("GPU Fields data broadcast addition:")
println("\tData size: $data_size_fields_gpu")
println("\tBandwidth: $gpu_fields_bandwidth GB/s")
println("\tTime taken: $(ns_to_ms(median(gpu_fields_results.times))) ms\n")

println("GPU Field Operator broadcast addition:")
println("\tData size: $data_size_fo_gpu")
println("\tBandwidth: $gpu_fo_bandwidth GB/s")
println("\tTime taken: $(ns_to_ms(median(gpu_fo_results.times))) ms\n")
