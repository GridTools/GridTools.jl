using Test
using GridTools
using GridTools.ExampleMeshes.Unstructured
using GridTools.ExampleMeshes.Cartesian
using MacroTools

function print_debug_info(title::String, mat::Matrix)::Nothing
    println("----------------------------------------------------------------------------")
    println(title)
    display(mat)
end

function setup_cartesian_offset_provider()
    return Dict{String, Dimension}(
                    "Ioff" => IDim,
                    "Joff" => JDim
                    )
end

function constant_cartesian_field()::Field
    return Field((IDim, JDim), ones(Float64, 8, 8))
end

function lap_reference(in_field_data::Matrix{Float64}, initialized_out_field_data::Matrix{Float64})::Matrix{Float64}
    nrows, ncols = size(in_field_data)
    @assert nrows >= 3 && ncols >= 3 "Input matrix must be at least 3x3 to compute stencil operations."

    out_field_data = deepcopy(initialized_out_field_data)

    for i in 2:(nrows - 1)
        for j in 2:(ncols - 1)
            # Perform the stencil operation
            out_field_data[i-1, j-1] = -4 * in_field_data[i, j] + 
                                in_field_data[i+1, j]   + 
                                in_field_data[i-1, j]   + 
                                in_field_data[i, j+1]   + 
                                in_field_data[i, j-1]
        end
    end

    return out_field_data
end

@field_operator function lap(in_field::Field{Tuple{IDim_, JDim_}, Float64})
    in_field_sliced = slice(in_field, 2:7, 2:7)

    display(-4.0*in_field .+
    in_field(Ioff[1]) .+
    in_field(Ioff[-1]) .+
    in_field(Joff[1]) .+
    in_field(Joff[-1]))
    return -4.0*in_field_sliced .+
    slice(in_field(Ioff[1]), 2:7, 2:7)  .+
    slice(in_field(Ioff[-1]), 2:7, 2:7) .+
    slice(in_field(Joff[1]), 2:7, 2:7) .+
    slice(in_field(Joff[-1]), 2:7, 2:7)
end

function test_lap(offset_provider::Dict{String, Dimension}, backend::String, field_generator::Function, debug::Bool=false)
    in_field = field_generator()
    x_length, y_length = size(in_field.data)
    out_field = Field((IDim, JDim), ones(Float64, x_length-2, y_length-2), origin=Dict(IDim => 1, JDim => 1))
    expected_out_data = lap_reference(in_field.data, out_field.data)

    lap(in_field, offset_provider=offset_provider, backend=backend, out=out_field)
    
    if debug
        print_debug_info("Input Matrix before applying the laplacian:", in_field.data)
        print_debug_info("Output Matrix after applying lap() operator in the field operator:", out_field.data)
        print_debug_info("Expected reference of laplacian computation without field operator:", expected_out_data)
        print("\n\n")
    end

    @test out_field.data == expected_out_data
end


offset_provider = setup_cartesian_offset_provider()

test_lap(offset_provider,"embedded", constant_cartesian_field, true)