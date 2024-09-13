using Test
using CUDA: CuArray
using GridTools
using GridTools.ExampleMeshes.Unstructured

@testset "Testset Simple Broadcast Addition GPU" begin
    a_gpu = Field(Cell, CuArray(1.0:15.0))
    b_gpu = Field(Cell, CuArray(-2.0:-1:-16.0))
    @assert size(a_gpu.data) == size(b_gpu.data) "Fields a_gpu and b_gpu do not have the same size of data."

    out_gpu = similar_field(a_gpu)
    out_gpu = a_gpu .+ b_gpu

    @test all(out_gpu.data .== -1)    
end

@testset "Testset Large Broadcast Addition GPU" begin
    # Initialize two large GPU fields with CuArray
    a_gpu = Field(Cell, CuArray(1:2e7))
    b_gpu = Field(Cell, CuArray(1:2e7))
    @assert size(a_gpu.data) == size(b_gpu.data) "Fields a_gpu and b_gpu do not have the same size of data."

    out_gpu = similar_field(a_gpu)
    out_gpu .= a_gpu .+ b_gpu

    expected_result = CuArray(2:2:2e7*2)
    
    @test all(out_gpu.data .== expected_result)
end

@testset "Testset Field Operator Addition GPU" begin
    a_gpu = Field(Cell, CuArray(1.0:15.0))
    b_gpu = Field(Cell, CuArray(-2.0:-1:-16.0))
    @assert size(a_gpu.data) == size(b_gpu.data) "Fields a and b do not have the same size of data."

    out_gpu = similar_field(a_gpu)

    @field_operator function fo_addition(a::Field{Tuple{Cell_},Float64}, b::Field{Tuple{Cell_},Float64})::Field{Tuple{Cell_},Float64}
        return a .+ b
    end

    fo_addition(a_gpu, b_gpu, backend="embedded", out=out_gpu)
    @test all(out_gpu.data .== -1)
end
