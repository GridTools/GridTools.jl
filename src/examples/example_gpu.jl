using GridTools
using GridTools.ExampleMeshes.Unstructured
using CUDA
using Profile
using Debugger
using BenchmarkTools

# Cpu

a_cpu = Field(Cell, collect(1:2e7))
b_cpu = Field(Cell, collect(1:2e7))

out_cpu = similar(a_cpu)

out_cpu = a_cpu .+ b_cpu

# Gpu

a_gpu = Field(Cell, CuArray(1:2e7))
b_gpu = Field(Cell, CuArray(1:2e7))

out_gpu = similar_field(a_gpu)

out_gpu .= a_gpu .+ b_gpu

function bench_cpu!(a_cpu, b_cpu, out_cpu)
    out_cpu = a_cpu .+ b_cpu
end

function bench_gpu!(a_gpu, b_gpu, out_gpu)
    # Wrapping the execution in a CUDA.@sync block will make 
    # the CPU block until the queued GPU tasks are done, similar to how Base.@sync waits for distributed CPU tasks
    CUDA.@sync begin
        out_gpu = a_gpu .+ b_gpu
    end
end

@btime bench_cpu!($a_cpu, $b_cpu, $out_cpu)
@btime bench_gpu!($a_gpu, $b_gpu, $out_gpu)