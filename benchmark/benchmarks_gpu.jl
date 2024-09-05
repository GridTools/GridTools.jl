using BenchmarkTools
using CUDA
using GridTools
using GridTools.ExampleMeshes.Unstructured

# Data size
const STREAM_SIZE::Int64 = 10_000_000

"""
    compute_memory_bandwidth_addition(time_in_seconds, a, b, out)::Tuple{Float64, Int64}

Function to compute the memory bandwidth for the addition benchmarks.

# Arguments
- `time_in_seconds`: The execution time in seconds.
- `STREAM_SIZE`: the size used for the arrays

# Returns
- A tuple `(bandwidth, data_size)` where:
    - `bandwidth`: The memory bandwidth in gigabytes per second (GB/s).
    - `data_size`: The total size of the data processed in bytes.
"""
function compute_memory_bandwidth_addition(time_in_seconds::Float64, STREAM_SIZE::Int64, data_type::Type)::Tuple{Float64, Int64}
    # Calculate the total size of data read and written in bytes
    data_size = 3 * STREAM_SIZE * sizeof(data_type)  # (a + b + out), each Float64 is 8 bytes

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
- `a_gpu`, `b_gpu`, `out_gpu`: Three CuArray GPU arrays of size `ARRAY_SIZE`.
"""
function gpu_broadcast_addition_setup(ARRAY_SIZE::Int64)::Tuple{CuArray{Float64,1}, CuArray{Float64,1}, CuArray{Float64,1}}
    randcuarr = () -> CuArray(rand(Float64, ARRAY_SIZE))
    a_gpu = randcuarr()
    b_gpu = randcuarr()
    out_gpu = randcuarr()
    return a_gpu, b_gpu, out_gpu
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
    randfieldcuarr = () -> Field(Cell, CuArray(rand(Float64, FIELD_DATA_SIZE)))
    a_gpu = randfieldcuarr()
    b_gpu = randfieldcuarr()
    out_gpu = randfieldcuarr()
    return a_gpu, b_gpu, out_gpu
end

# CuArray only
function arr_add_wrapper!(out::CuArray{Float64,1}, a::CuArray{Float64,1}, b::CuArray{Float64,1})
    CUDA.@sync begin
        out = a .+ b
    end
end

# Fields only
function field_add_wrapper!(out::Field{Tuple{Cell_},Float64}, a::Field{Tuple{Cell_},Float64}, b::Field{Tuple{Cell_},Float64})
    CUDA.@sync begin
        out = a .+ b
    end
end

# Field operator
@field_operator function gpu_fo_addition(a::Field{Tuple{Cell_},Float64}, b::Field{Tuple{Cell_},Float64})::Field{Tuple{Cell_},Float64}
    return a .+ b
end

function gpu_fo_addition_wrapper!(out::Field{Tuple{Cell_},Float64}, a::Field{Tuple{Cell_},Float64}, b::Field{Tuple{Cell_},Float64})
    CUDA.@sync begin
        gpu_fo_addition(a, b, backend="embedded", out=out)
    end
end

# Benchmarks with @belapsed

# CuArray  -----------------------------------------------------------------------------------------------------------
a_gpu, b_gpu, out_gpu = gpu_broadcast_addition_setup(STREAM_SIZE)

println("Benchmarking GPU array broadcast addition:")
gpu_array_time = @belapsed arr_add_wrapper!($out_gpu, $a_gpu, $b_gpu)

# Compute memory bandwidth for GPU array benchmark
gpu_array_bandwidth, data_size_arr_gpu = compute_memory_bandwidth_addition(gpu_array_time, STREAM_SIZE, eltype(a_gpu))
println("GPU Array broadcast addition:")
println("\tData size: $data_size_arr_gpu")
println("\tTime:      $gpu_array_time")
println("\tBandwidth: $gpu_array_bandwidth GB/s\n")

# Fields  -------------------------------------------------------------------------------------------------------------
a_gpu, b_gpu, out_gpu = gpu_fields_broadcast_addition_setup(STREAM_SIZE)

println("Benchmarking GPU fields broadcast addition:")
gpu_fields_time = @belapsed field_add_wrapper!($out_gpu, $a_gpu, $b_gpu)

# Compute memory bandwidth for GPU fields benchmark
gpu_fields_bandwidth, data_size_fields_gpu = compute_memory_bandwidth_addition(gpu_fields_time, STREAM_SIZE, eltype(a_gpu.data))
println("GPU Fields broadcast addition:")
println("\tData size: $data_size_fields_gpu")
println("\tTime:      $gpu_fields_time")
println("\tBandwidth: $gpu_fields_bandwidth GB/s\n")

# Field operator -------------------------------------------------------------------------------------------------------
a_gpu, b_gpu, out_gpu = gpu_fields_broadcast_addition_setup(STREAM_SIZE)

println("Benchmarking GPU field operator broadcast addition:")
gpu_fo_time = @belapsed field_add_wrapper!($out_gpu, $a_gpu, $b_gpu)

# Compute memory bandwidth for GPU field operator benchmark
gpu_fo_bandwidth, data_size_fo_gpu = compute_memory_bandwidth_addition(gpu_fo_time, STREAM_SIZE, eltype(a_gpu.data))
println("GPU Field Operator broadcast addition:")
println("\tData size: $data_size_fo_gpu")
println("\tBandwidth: $gpu_fo_bandwidth GB/s\n")
