using Test
using GridTools
using GridTools.ExampleMeshes.Unstructured
using GridTools.ExampleMeshes.Cartesian
using MacroTools

struct TestFailedException <: Exception
    message::String
end

macro to_py(expr::Expr)
    res = quote
        try
            $(esc(expr))
            true
        catch e
            throw(TestFailedException("The following test: $($(string(namify(expr)))) encountered following error: $e"))
        end
    end
    return res
end

# Utility ----------------------------------------------------------------------------------------------------

"""
    testwrapper(setupfunc::Union{Function,Nothing}, testfunc::Function, args...)

Wrapper function to facilitate testing with optional setup.

# Arguments
- `setupfunc::Union{Function,Nothing}`: An optional setup function. If provided, it will be called before the test function. 
                                        If `nothing`, the test function is called directly.
- `testfunc::Function`: The test function to be executed.
- `args...`: Additional arguments to be passed to the test function.

# Usage
- If `setupfunc` is provided, it should return the necessary data that `testfunc` will use. 
  The returned data will be passed as the first argument to `testfunc`, followed by `args...`.
- If `setupfunc` is `nothing`, `testfunc` will be called directly with `args...`.

# Examples

## Example 1: Without Setup Function
```julia
function mytest(args...)
    println("Running test with arguments: ", args)
end

testwrapper(nothing, mytest, 1, 2, 3)
# Output: Running test with arguments: (1, 2, 3)
```

## Example 2: With Setup Function
```julia
function setup()
    return "setup data"
end

function mytest(data, args...)
    println("Setup data: ", data)
    println("Running test with arguments: ", args)
end

testwrapper(setup, mytest, 1, 2, 3)
# Output: 
# Setup data: setup data
# Running test with arguments: (1, 2, 3)
```
"""
function testwrapper(setupfunc::Union{Function,Nothing}, testfunc::Function, args...)
    args_str = join(map(string, args), ", ")
    println("Executing '$(nameof(testfunc))' with args: $args_str")
    if setupfunc === nothing
        testfunc(args...)
    else
        data = setupfunc()
        testfunc(data, args...)
    end
end

function print_debug_info(title::String, mat::Matrix)::Nothing
    println("----------------------------------------------------------------------------")
    println(title)
    display(mat)
end

function copy_borders!(dest_matrix::Matrix{Float64}, src_matrix::Matrix{Float64}, border_width::Int)
    nrows, ncols = size(src_matrix)
    
    # Ensure both matrices have the same size and the border width is feasible
    @assert size(dest_matrix) == size(src_matrix) "Both matrices must be of the same size"
    @assert border_width > 0 && border_width <= nrows ÷ 2 && border_width <= ncols ÷ 2 "Border width must be positive and less than half the smallest dimension"

    # Top and bottom border rows
    dest_matrix[1:border_width, :] .= src_matrix[1:border_width, :]
    dest_matrix[(nrows-border_width+1):end, :] .= src_matrix[(nrows-border_width+1):end, :]

    # Left and right border columns
    dest_matrix[:, 1:border_width] .= src_matrix[:, 1:border_width]
    dest_matrix[:, (ncols-border_width+1):end] .= src_matrix[:, (ncols-border_width+1):end]

    return dest_matrix
end

function lap_reference(in_field_data::Matrix{Float64})::Matrix{Float64}
    nrows, ncols = size(in_field_data)
    @assert nrows >= 3 && ncols >= 3 "Input matrix must be at least 3x3 to compute stencil operations."

    out_field_data = similar(in_field_data)

    for i in 2:(nrows - 1)
        for j in 2:(ncols - 1)
            # Perform the stencil operation
            out_field_data[i, j] = -4 * in_field_data[i, j] + 
                                in_field_data[i+1, j]   + 
                                in_field_data[i-1, j]   + 
                                in_field_data[i, j+1]   + 
                                in_field_data[i, j-1]
        end
    end

    copy_borders!(out_field_data, in_field_data, 1) # Border values are not computed with the stencil operation
    return out_field_data
end

function lap_lap_reference(in_field_data::Matrix{Float64})
    x_length, y_length = size(in_field_data)
    @assert x_length >= 5 && y_length >= 5 "Input matrix must be at least 5x5 to compute double laplacian."

    out_field_data = similar(in_field_data)

    out_field_data = lap_reference(lap_reference(in_field_data)) 

    copy_borders!(out_field_data, in_field_data, 2) # Border values are not computed with the stencil operation
    return out_field_data
end

# Setup ------------------------------------------------------------------------------------------------------

function setup_simple_connectivity()::Dict{String,Connectivity}
    edge_to_cell_table = [
        [1 -1];
        [3 -1];
        [3 -1];
        [4 -1];
        [5 -1];
        [6 -1];
        [1 6];
        [1 2];
        [2 3];
        [2 4];
        [4 5];
        [5 6]
    ]

    cell_to_edge_table = [
        [1 7 8];
        [8 9 10];
        [2 3 9];
        [4 10 11];
        [5 11 12];
        [6 7 12]
    ]

    E2C_offset_provider = Connectivity(edge_to_cell_table, Cell, Edge, 2)
    C2E_offset_provider = Connectivity(cell_to_edge_table, Edge, Cell, 3)

    offset_provider = Dict{String,Connectivity}(
        "E2C" => E2C_offset_provider,
        "C2E" => C2E_offset_provider,
        "E2CDim" => E2C_offset_provider # TODO(lorenzovarese): this is required for the embedded backend (note: python already uses E2C)
    )

    return offset_provider
end

function setup_cartesian_offset_provider()
    return Dict{String, Dimension}(
                    "Ioff" => IDim,
                    "Joff" => JDim
                    )
end

function field_increasing_values()
    return Field(Cell, collect(1.0:15.0))
end

function field_decreasing_values()
    return Field(Cell, collect(15.0:-1:1.0))
end

function constant_cartesian_field()::Field
    return Field((IDim, JDim), ones(Float64, 8, 8))
end

function simple_cartesian_field()::Field
    return Field((IDim, JDim), [Float64((i-1) * 5 + j-1) for i in 1:5, j in 1:5])
end

    # return Field(Cell, 15.0:-1:1.0) TODO: adjust this computation

function test_fo_addition(backend::String)
    a = Field(Cell, collect(1.0:15.0))
    b = Field(Cell, collect(-1.0:-1:-15.0))
    @assert size(a.data) == size(b.data) "Fields a and b do not have the same size of data."

    out_field = similar_field(a)

    @field_operator function fo_addition(a::Field{Tuple{Cell_},Float64}, b::Field{Tuple{Cell_},Float64})::Field{Tuple{Cell_},Float64}
        return a .+ b
    end

    fo_addition(a, b, backend=backend, out=out_field)
    @test all(out_field.data .== 0)
end

function test_fo_cartesian_offset(backend::String)
    a = Field(K, collect(1.0:15.0))
    out_field = Field(K, zeros(Float64, 14)) # field is one smaller since we shift by one

    @field_operator function fo_cartesian_offset(inp::Field{Tuple{K_},Float64})::Field{Tuple{K_},Float64}
        return inp(Koff[1])
    end

    fo_cartesian_offset(a, backend=backend, out=out_field, offset_provider=Dict("Koff" => K))
    @test all(out_field.data .== 2.0:15.0)
end

function test_fo_scalar_multiplication(backend::String)
    a = Field(Cell, collect(1.0:15.0))
    out_field = similar_field(a)

    @field_operator function fo_scalar_mult(inp::Field{Tuple{Cell_},Float64})::Field{Tuple{Cell_},Float64}
        return 4.0*inp
    end

    fo_scalar_mult(a, backend=backend, out=out_field, offset_provider=Dict("Koff" => K))
    @test all(out_field.data .== 4*(1.0:15.0))
end

function test_fo_cartesian_offset_composed(backend::String)
    a = Field(K, collect(1.0:15.0))
    out_field = Field(K, zeros(Float64, 12)) # field is one smaller since we shift by one

    @field_operator function fo_cartesian_offset_composed(inp::Field{Tuple{K_},Float64})::Field{Tuple{K_},Float64}
        tmp = inp(Koff[1])
        return tmp(Koff[2])
    end

    fo_cartesian_offset_composed(a, backend=backend, out=out_field, offset_provider=Dict("Koff" => K))
    @test all(out_field.data .== 4.0:15.0)
end

function test_fo_nested_if_else(backend::String)
    a = Field(Cell, collect(Int32, 1:15))  # TODO(tehrengruber): if we don't use the right dtype here we get a horrible error in python
    out_field = similar_field(a)

    @field_operator function fo_nested_if_else(f::Field{Tuple{Cell_},Int32})::Field{Tuple{Cell_},Int32}
        tmp = f
        if 1.0 < 10.0
            # TODO: The Int32 cast is ugly, but required to have consistent behaviour between embedded and GT4Py.
            #  We should fix the design.
            tmp = f .+ Int32(1)
            if 30 > 5
                tmp = tmp .+ Int32(20)
                tmp = tmp .- Int32(10)
            elseif 40 < 4
                tmp = 4 == 5 ? tmp : tmp .- 100
            else
                tmp = tmp .* 5
            end
            tmp = tmp .+ Int32(10)
        elseif 10 < 20
            tmp = f .- 1
        else
            tmp = tmp .* 10
            tmp = tmp .+ 10
            tmp = tmp .+ 100
        end
        return tmp
    end

    fo_nested_if_else(a, backend=backend, out=out_field)
    @test all(out_field.data .== collect(22:36))
end

function test_fo_remapping(offset_provider::Dict{String,Connectivity}, backend::String)
    a = Field(Cell, collect(1.0:15.0))
    expected_output = a[offset_provider["E2C"][:, 1]] # First column of the edge to cell connectivity table

    out_field = Field(Edge, similar(expected_output))

    @field_operator function fo_remapping(a::Field{Tuple{Cell_},Float64})::Field{Tuple{Edge_},Float64}
        return a(E2C[1])
    end

    fo_remapping(a, offset_provider=offset_provider, backend=backend, out=out_field)
    @test all(out_field.data .== expected_output)
end

function test_fo_neighbor_sum(offset_provider::Dict{String,Connectivity}, backend::String)
    a = Field(Cell, collect(5.0:17.0)*3)
    out_field = Field(Edge, zeros(Float64, 12))
    
    # Function to sum only the positive elements of each inner vector (to exclude the -1 in the connectivity)
    function sum_positive_elements(v, field_data)
        return sum(idx -> idx != -1 ? field_data[idx] : 0, v)
    end

    # Compute the reference manually computing the sum on that dimension
    edge_to_cell_data = offset_provider["E2C"].data
    expected_output = Float64[]
    for i in axes(edge_to_cell_data, 1)
        push!(expected_output, sum_positive_elements(edge_to_cell_data[i, :], a))
    end

    @field_operator function fo_neighbor_sum(a::Field{Tuple{Cell_},Float64})::Field{Tuple{Edge_},Float64}
        return neighbor_sum(a(E2C), axis=E2CDim)
    end

    fo_neighbor_sum(a, offset_provider=offset_provider, backend=backend, out=out_field)
    @test out_field == expected_output
end

function compute_expected_output_comparing_values(offset_provider::Dict{String, Connectivity}, a::Field{Tuple{Cell_}, Float64}, operation::Function)
    expected_output = Field(Edge, zeros(Float64, 12))
    E2C = offset_provider["E2C"]
    for edge in 1:length(expected_output.data)
        # Extract the neighboring cell indices for the current edge
        neighbor_cells = E2C.data[edge, :]
        # Filter out the -1 indices
        valid_neighbors = filter(x -> x != -1, neighbor_cells)
        # Compute the maximum/minimum value among the valid neighbors
        if !isempty(valid_neighbors)
            expected_output.data[edge] = operation(a[valid_neighbors])
        else
            throw("E2C Connectivity is not defined correctly. An edge cannot have no neighbors.")
        end
    end
    return expected_output
end

function test_fo_max_over(offset_provider::Dict{String,Connectivity}, backend::String, generate_field::Function)
    a::Field = generate_field()
    out_field = Field(Edge, zeros(Float64, 12))

    # Compute the reference manually computing the maximum of the value of each neighbor
    expected_output = expected_output = compute_expected_output_comparing_values(offset_provider, a, maximum)

    @field_operator function fo_max_over(a::Field{Tuple{Cell_},Float64})::Field{Tuple{Edge_},Float64}
        return max_over(a(E2C), axis=E2CDim)
    end

    fo_max_over(a, offset_provider=offset_provider, backend=backend, out=out_field)
    @test out_field == expected_output
end

function test_fo_min_over(offset_provider::Dict{String,Connectivity}, backend::String, generate_field::Function)
    a::Field = generate_field()
    out_field = Field(Edge, zeros(Float64, 12))

    # Compute the reference manually computing the minimum of the value of each neighbor
    expected_output = compute_expected_output_comparing_values(offset_provider, a, minimum)

    @field_operator function fo_min_over(a::Field{Tuple{Cell_},Float64})::Field{Tuple{Edge_},Float64}
        return min_over(a(E2C), axis=E2CDim)
    end

    fo_min_over(a, offset_provider=offset_provider, backend=backend, out=out_field)
    @test out_field == expected_output
end

function test_fo_simple_broadcast(backend::String)
    broadcast_num_dims = 5
    a = Field(Cell, collect(1.0:15.0))

    # Compute the expected output by broadcasting a
    expected_output = [a[i] for i in 1:15, j in 1:broadcast_num_dims]

    out_field = Field((Cell, K), similar(expected_output))

    @field_operator function fo_simple_broadcast(a::Field{Tuple{Cell_},Float64})::Field{Tuple{Cell_,K_},Float64}
        return broadcast(a, (Cell, K))
    end

    fo_simple_broadcast(a, backend=backend, out=out_field)
    @test out_field == expected_output
end

function test_fo_scalar_broadcast(backend::String)
    # Compute the expected output by broadcasting the value
    expected_output = fill(5.0, (10, 10))

    out_field = Field((Cell, K), similar(expected_output))

    @field_operator function fo_scalar_broadcast()::Field{Tuple{Cell_,K_},Float64}
        return broadcast(5.0, (Cell, K))
    end

    fo_scalar_broadcast(backend=backend, out=out_field)
    @test out_field == expected_output
end

function test_fo_where(backend::String)
    a = Field((Cell, K), reshape(collect(1.0:10.0), (5, 2))) # The matrix is filled column major
    b = Field((Cell, K), fill(-1.0, (5, 2)))
    mask = Field((Cell, K), [true  false; 
                             false true; 
                             true  false; 
                             false false; 
                             true  true  ])
    out_field = similar_field(a)

    expected_output =  [ 1 -1
                        -1  7
                         3 -1
                        -1 -1
                         5 10 ]

    @field_operator function fo_where(mask::Field{Tuple{Cell_,K_},Bool}, a::Field{Tuple{Cell_,K_},Float64}, b::Field{Tuple{Cell_,K_},Float64})::Field{Tuple{Cell_,K_},Float64}
        return where(mask, a, b)
    end

    fo_where(mask, a, b, backend=backend, out=out_field)
    @test out_field == expected_output 
end

function test_fo_astype(backend::String)
    a = Field((Cell, K), reshape(collect(1.0:12.0), (6, 2))) # Floating Point
    out_field = similar_field(a, Int64) # Integer

    expected_values = reshape(collect(1.0:12.0), (6, 2))

    @field_operator function fo_astype(a::Field{Tuple{Cell_,K_},Float64})::Field{Tuple{Cell_,K_},Int64}
        return convert(Int64, a) # Integer
    end

    fo_astype(a, backend=backend, out=out_field)
    @test out_field == expected_values
    @test eltype(out_field.data) == Int64
    @test eltype(a.data) == Float64
end

function test_fo_sin(backend::String)
    a = Field((Cell, K), reshape(collect(1.0:12.0), (6, 2)))
    out_field = similar_field(a)

    # Compute the expected output using the sin function
    expected_output = sin.(reshape(collect(1.0:12.0), (6, 2)))

    @field_operator function fo_sin(a::Field{Tuple{Cell_,K_},Float64})::Field{Tuple{Cell_,K_},Float64}
        return sin.(a)
    end

    fo_sin(a, backend=backend, out=out_field)
    @test isapprox(out_field.data, expected_output, atol=1e-6)
end

function test_fo_asinh(backend::String)
    a = Field((Cell, K), reshape(collect(1.0:12.0), (6, 2)))
    out_field = similar_field(a)

    # Compute the expected output using the asinh function
    expected_output = asinh.(reshape(collect(1.0:12.0), (6, 2)))

    @field_operator function fo_asinh(a::Field{Tuple{Cell_,K_},Float64})::Field{Tuple{Cell_,K_},Float64}
        return asinh.(a)
    end

    fo_asinh(a, backend=backend, out=out_field)
    @test isapprox(out_field.data, expected_output, atol=1e-6)
end

function test_fo_offset_array(backend::String)
    A = Field((Vertex, K), reshape(collect(1.0:15.0), 3, 5), origin=Dict(Vertex => -2, K => -1))
    B = Field((K, Edge), reshape(ones(6), 3, 2))

    out = Field((Vertex, K, Edge), zeros(3, 3, 2))

    @field_operator function fo_offset_array(A::Field{Tuple{Vertex_,K_},Float64}, B::Field{Tuple{K_,Edge_},Float64})::Field{Tuple{Vertex_,K_,Edge_},Float64}
        return A .+ B
    end

    @test @to_py fo_offset_array(A, B, backend=backend, out=out) # Simply check if the execution is performed
    println("test_fo_offset_array - backend->[", backend, "] - output: ", out.data)
    # @test out == expected_output
end

function test_nested_fo(backend::String)
    a = Field(Cell, collect(1.0:15.0))
    b = Field(Cell, ones(15))
    out_field = similar_field(a)

    # Compute the Reference
    intermediate_result = a.data .+ b.data
    expected_output = intermediate_result .+ a.data

    @field_operator function fo_addition(a::Field{Tuple{Cell_},Float64}, b::Field{Tuple{Cell_},Float64})::Field{Tuple{Cell_},Float64}
        return a .+ b
    end

    @field_operator function nested_fo(a::Field{Tuple{Cell_},Float64}, b::Field{Tuple{Cell_},Float64})::Field{Tuple{Cell_},Float64}
        res = fo_addition(a, b)
        return res .+ a
    end

    nested_fo(a, b, backend=backend, out=out_field)

    # Test against the reference
    @test out_field.data == expected_output
end

# Define the Laplacian field operation in the global scope for accessibility across multiple tests.
@field_operator function lap(in_field::Field{Tuple{IDim_, JDim_}, Float64})
    return -4.0*in_field +
        in_field(Ioff[1]) +
        in_field(Ioff[-1]) +
        in_field(Joff[1]) +
        in_field(Joff[-1])
end

function test_lap(offset_provider::Dict{String, Dimension}, backend::String, field_generator::Function, debug::Bool=false)
    in_field = field_generator()
    x_length, y_length = size(in_field.data)
    out_field = Field((IDim, JDim), zeros(Float64, x_length, y_length))
    expected_out = lap_reference(in_field.data)

    lap(in_field, offset_provider=offset_provider, backend=backend, out=out_field)
    
    if debug
        print_debug_info("Input Matrix before applying the laplacian:", in_field.data)
        print_debug_info("Output Matrix after applying lap() operator in the field operator:", out_field.data)
        print_debug_info("Expected reference of laplacian computation without field operator:", expected_out)
        print("\n\n")
    end

    @test out_field.data[2:end-1, 2:end-1] == expected_out[2:end-1, 2:end-1]

    # TODO: add in the future the test for the border values
    # @test out_field.data[1, :] == expected_out[1, :] && out_field.data[end, :] == expected_out[end, :] \
    #  out_field.data[:, 1] == expected_out[:, 1] && out_field.data[:, end] == expected_out[:, end]
end

function test_lap_lap(offset_provider::Dict{String, Dimension}, backend::String, field_generator::Function, debug::Bool=false)
    in_field = field_generator()
    x_length, y_length = size(in_field.data)
    out_field = Field((IDim, JDim), zeros(Float64, x_length, y_length))
    expected_out = lap_lap_reference(in_field.data)

    @field_operator function lap_lap(in_field::Field{Tuple{IDim_, JDim_}, Float64})
        return lap(lap(in_field))
    end

    lap_lap(in_field, offset_provider=offset_provider, backend=backend, out=out_field)

    if debug
        print_debug_info("Input Matrix before applying the laplacian of laplacian (lap_lap):", in_field.data)
        print_debug_info("Output Matrix after applying lap(lap()) operator in the field operator:", out_field.data)
        print_debug_info("Expected reference of lap(lap()) computation without field operator:", expected_out)
        print("\n\n")
    end

    @test out_field.data[3:end-2, 3:end-2] == expected_out[3:end-2, 3:end-2]
    # TODO: add in the future the test for the border values
end

# Test Executions --------------------------------------------------------------------------------------------

function test_gt4py_fo_exec()
    testwrapper(nothing, test_fo_addition, "embedded")
    testwrapper(nothing, test_fo_addition, "py")

    testwrapper(nothing, test_fo_scalar_multiplication, "embedded")
    testwrapper(nothing, test_fo_scalar_multiplication, "py")

    testwrapper(nothing, test_fo_cartesian_offset, "embedded")
    testwrapper(nothing, test_fo_cartesian_offset, "py")

    testwrapper(nothing, test_fo_cartesian_offset_composed, "embedded")
    testwrapper(nothing, test_fo_cartesian_offset_composed, "py")

    testwrapper(nothing, test_fo_nested_if_else, "embedded")
    testwrapper(nothing, test_fo_nested_if_else, "py")

    testwrapper(setup_simple_connectivity, test_fo_remapping, "embedded")
    testwrapper(setup_simple_connectivity, test_fo_remapping, "py")

    testwrapper(setup_simple_connectivity, test_fo_neighbor_sum, "embedded")
    testwrapper(setup_simple_connectivity, test_fo_neighbor_sum, "py")

    testwrapper(setup_simple_connectivity, test_fo_max_over, "embedded", field_increasing_values)
    testwrapper(setup_simple_connectivity, test_fo_max_over, "py", field_increasing_values)

    testwrapper(setup_simple_connectivity, test_fo_max_over, "embedded", field_decreasing_values)
    testwrapper(setup_simple_connectivity, test_fo_max_over, "py", field_decreasing_values)

    testwrapper(setup_simple_connectivity, test_fo_min_over, "embedded", field_increasing_values)
    testwrapper(setup_simple_connectivity, test_fo_min_over, "py", field_increasing_values)

    testwrapper(setup_simple_connectivity, test_fo_min_over, "embedded", field_decreasing_values)
    testwrapper(setup_simple_connectivity, test_fo_min_over, "py", field_decreasing_values)

    testwrapper(nothing, test_fo_simple_broadcast, "embedded")
    testwrapper(nothing, test_fo_simple_broadcast, "py")

    testwrapper(nothing, test_fo_scalar_broadcast, "embedded")
    testwrapper(nothing, test_fo_scalar_broadcast, "py")

    testwrapper(nothing, test_fo_where, "embedded")
    testwrapper(nothing, test_fo_where, "py")

    testwrapper(nothing, test_fo_astype, "embedded")
    testwrapper(nothing, test_fo_astype, "py")

    testwrapper(nothing, test_fo_sin, "embedded")
    testwrapper(nothing, test_fo_sin, "py")

    testwrapper(nothing, test_fo_asinh, "embedded")
    testwrapper(nothing, test_fo_asinh, "py")

    # TODO(tehrengruber): disabled for now until we understand what it is supposed to do
    #testwrapper(nothing, test_fo_offset_array, "embedded")
    #testwrapper(nothing, test_fo_offset_array, "py")

    testwrapper(nothing, test_nested_fo, "embedded")
    testwrapper(nothing, test_nested_fo, "py")

    # TODO: add support for the embedded backend when the dims is changing due to cartesian offsets
    # (Note: check the debug flag for pretty printing the outputs)
    # testwrapper(setup_cartesian_offset_provider, test_lap, "embedded", constant_cartesian_field)
    testwrapper(setup_cartesian_offset_provider, test_lap, "py", constant_cartesian_field)

    # testwrapper(setup_cartesian_offset_provider, test_lap, "embedded", simple_cartesian_field)
    testwrapper(setup_cartesian_offset_provider, test_lap, "py", simple_cartesian_field)

    # testwrapper(setup_cartesian_offset_provider, test_lap_lap, "embedded", constant_cartesian_field)
    testwrapper(setup_cartesian_offset_provider, test_lap_lap, "py", constant_cartesian_field)
    
    # testwrapper(setup_cartesian_offset_provider, test_lap_lap, "embedded", simple_cartesian_field)
    testwrapper(setup_cartesian_offset_provider, test_lap_lap, "py", simple_cartesian_field)
end

@testset "Testset GT2Py fo exec" test_gt4py_fo_exec()
