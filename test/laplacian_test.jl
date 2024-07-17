using Test
using Printf
using GridTools

include("mesh_definitions.jl")

const global IDim_ = Dimension{:IDim_, HORIZONTAL}
const global JDim_ = Dimension{:JDim_, HORIZONTAL}
const global IDim = IDim_()
const global JDim = JDim_()

const Ioff = FieldOffset("Ioff", source=IDim, target=IDim)
const Joff = FieldOffset("Joff", source=JDim, target=JDim)

offset_provider = Dict{String, Dimension}(
                   "Ioff" => IDim,
                   "Joff" => JDim
                )

function test_lap(in_field::Field)
    out_field = Field((IDim, JDim), zeros(Float64, 8, 8))
    
    @field_operator function lap(in_field::Field{Tuple{IDim_, JDim_}, Float64})
        return -4.0*in_field +
            in_field(Ioff[1]) +
            in_field(Ioff[-1]) +
            in_field(Joff[1]) +
            in_field(Joff[-1])
    end

    lap(in_field, offset_provider=offset_provider, backend="py", out=out_field)
    
    println("\nOutput Matrix after applying lap() operator:")
    pretty_print_matrix(out_field.data)
end

function test_lap_lap(in_field::Field)
    out_field = Field((IDim, JDim), zeros(Float64, 8, 8))

    @field_operator function lap(in_field::Field{Tuple{IDim_, JDim_}, Float64})
        return -4.0*in_field +
            in_field(Ioff[1]) +
            in_field(Ioff[-1]) +
            in_field(Joff[1]) +
            in_field(Joff[-1])
    end
    
    @field_operator function lap_lap(in_field::Field{Tuple{IDim_, JDim_}, Float64})
        tmp = lap(in_field)
        return lap(tmp)
    end

    lap_lap(in_field, offset_provider=offset_provider, backend="py", out=out_field)

    println("\nOutput Matrix after applying lap(lap()) operator:")
    pretty_print_matrix(out_field.data)
end

function pretty_print_matrix(mat::Matrix)::Nothing
    max_width = maximum(length(string(e)) for e in mat)

    for row in eachrow(mat)
        formatted_row = join([@sprintf("%*s", max_width, string(x)) for x in row], "  ")
        println(formatted_row)
    end
    return
end

function allocate_cartesian_case()::Field
    return Field((IDim, JDim), ones(Float64, 8, 8))
    #return Field((IDim, JDim), [Float64((i-1) * 10 + j-1) for i in 1:10, j in 1:10])
end

# Test Cases (on a manually defined 10x10 matrix (0..99))
function execute_laplacian_operations()
    # Create a 10x10 matrix populated with values from 0 to 99 using an array comprehension
    in_field = allocate_cartesian_case()
    
    # Print the original matrix
    println("Original in_field Matrix:")
    pretty_print_matrix(in_field.data)
    
    test_lap(in_field)

    test_lap_lap(in_field)
end

# Call the test function
execute_laplacian_operations()
