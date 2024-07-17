using Test
using Printf
using GridTools
using MacroTools

include("mesh_definitions.jl")

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

function pretty_print_matrix(mat::Matrix)::Nothing
    max_width = maximum(length(string(e)) for e in mat)

    for row in eachrow(mat)
        formatted_row = join([@sprintf("%*s", max_width, string(x)) for x in row], "  ")
        println(formatted_row)
    end
    return
end

function lap_ground_truth(in_field::Matrix{Float64})::Matrix{Float64}
    nrows, ncols = size(in_field)
    out_field = zeros(Float64, nrows, ncols) # Initialize out_field as a matrix of zeros
    out_field .= in_field # Copy inplace: to keep the initial values in the border
    for i in 2:(nrows - 1)
        for j in 2:(ncols - 1)
            # Perform the stencil operation
            out_field[i, j] = -4 * in_field[i, j] + 
                                in_field[i+1, j]   + 
                                in_field[i-1, j]   + 
                                in_field[i, j+1]   + 
                                in_field[i, j-1]
        end
    end

    return out_field
end

function lap_lap_ground_truth(in_field::Matrix{Float64})
    x_length, y_length = size(in_field)
    out_field = zeros(Float64, x_length, y_length)
    out_field .= in_field
    temp_field = lap_ground_truth(lap_ground_truth(in_field))  # Perform the laplap operation on the entire field
    out_field[3:end-2, 3:end-2] .= temp_field[3:end-2, 3:end-2] # Restrict the copy to avoid the copy in the unchanged border
    return out_field
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

function setup_constant_cartesian_domain()
    offset_provider = Dict{String, Dimension}(
                    "Ioff" => IDim,
                    "Joff" => JDim
                    )
    return offset_provider
end

function field_increasing_values()
    return Field(Cell, collect(1.0:15.0))
end

function field_decreasing_values()
    return Field(Cell, reverse(collect(1.0:15.0)))
end

function constant_cartesian_domain()::Field
    return Field((IDim, JDim), ones(Float64, 8, 8))
end

function simple_cartesian_domain()::Field
    return Field((IDim, JDim), [Float64((i-1) * 5 + j-1) for i in 1:5, j in 1:5])
end

# Test Definitions -------------------------------------------------------------------------------------------

function test_fo_addition(backend::String)
    a = Field(Cell, collect(1.0:15.0))
    b = Field(Cell, collect(-1.0:-1:-15.0))
    out = Field(Cell, zeros(Float64, 15))

    @field_operator function fo_addition(a::Field{Tuple{Cell_},Float64}, b::Field{Tuple{Cell_},Float64})::Field{Tuple{Cell_},Float64}
        return a .+ b
    end

    fo_addition(a, b, backend=backend, out=out)
    @test all(out.data .== 0)
end

function test_fo_cartesian_offset(backend::String)
    inp = Field(K, collect(1.0:15.0))
    out = Field(K, zeros(Float64, 14)) # field is one smaller since we shift by one

    @field_operator function fo_cartesian_offset(inp::Field{Tuple{K_},Float64})::Field{Tuple{K_},Float64}
        return inp(Koff[1])
    end

    fo_cartesian_offset(inp, backend=backend, out=out, offset_provider=Dict("Koff" => K))
    @test all(out.data .== 2.0:15.0)
end

function test_fo_scalar_multiplication(backend::String)
    inp = Field(Cell, collect(1.0:15.0))
    out = Field(Cell, zeros(Float64, 15))

    @field_operator function fo_scalar_mult(inp::Field{Tuple{Cell_},Float64})::Field{Tuple{Cell_},Float64}
        return 4.0*inp
    end

    fo_scalar_mult(inp, backend=backend, out=out, offset_provider=Dict("Koff" => K))
    @test all(out.data .== 4*(1.0:15.0))
end

function test_fo_cartesian_offset_composed(backend::String)
    inp = Field(K, collect(1.0:15.0))
    out = Field(K, zeros(Float64, 12)) # field is one smaller since we shift by one

    @field_operator function fo_cartesian_offset_composed(inp::Field{Tuple{K_},Float64})::Field{Tuple{K_},Float64}
        tmp = inp(Koff[1])
        return tmp(Koff[2])
    end

    fo_cartesian_offset_composed(inp, backend=backend, out=out, offset_provider=Dict("Koff" => K))
    @test all(out.data .== 4.0:15.0)
end

function test_fo_nested_if_else(backend::String)
    a = Field(Cell, collect(Int32, 1:15))  # TODO(tehrengruber): if we don't use the right dtype here we get a horrible error in python
    out = Field(Cell, zeros(Int32, 15))

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

    fo_nested_if_else(a, backend=backend, out=out)
    @test all(out.data .== collect(22:36))
end

function test_fo_remapping(offset_provider::Dict{String,Connectivity}, backend::String)
    a = Field(Cell, collect(1.0:15.0))
    out = Field(Edge, zeros(Float64, 12))
    expected_output = a[offset_provider["E2C"][:, 1]] # First column of the edge to cell connectivity table

    @field_operator function fo_remapping(a::Field{Tuple{Cell_},Float64})::Field{Tuple{Edge_},Float64}
        return a(E2C[1])
    end

    fo_remapping(a, offset_provider=offset_provider, backend=backend, out=out)
    @test all(out.data .== expected_output)
end

function test_fo_neighbor_sum(offset_provider::Dict{String,Connectivity}, backend::String)
    a = Field(Cell, collect(5.0:17.0)*3)
    out = Field(Edge, zeros(Float64, 12))
    
    # Function to sum only the positive elements of each inner vector (to exclude the -1 in the connectivity)
    function sum_positive_elements(v, field_data)
        return sum(idx -> idx != -1 ? field_data[idx] : 0, v)
    end

    # Compute the ground truth manually computing the sum on that dimension
    edge_to_cell_data = offset_provider["E2C"].data
    expected_output = Float64[]
    for i in axes(edge_to_cell_data, 1)
        push!(expected_output, sum_positive_elements(edge_to_cell_data[i, :], a))
    end

    @field_operator function fo_neighbor_sum(a::Field{Tuple{Cell_},Float64})::Field{Tuple{Edge_},Float64}
        return neighbor_sum(a(E2C), axis=E2CDim)
    end

    fo_neighbor_sum(a, offset_provider=offset_provider, backend=backend, out=out)
    @test out == expected_output
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
    out = Field(Edge, zeros(Float64, 12))

    # Compute the ground truth manually computing the maximum of the value of each neighbor
    expected_output = expected_output = compute_expected_output_comparing_values(offset_provider, a, maximum)

    @field_operator function fo_max_over(a::Field{Tuple{Cell_},Float64})::Field{Tuple{Edge_},Float64}
        return max_over(a(E2C), axis=E2CDim)
    end

    fo_max_over(a, offset_provider=offset_provider, backend=backend, out=out)
    @test out == expected_output
end

function test_fo_min_over(offset_provider::Dict{String,Connectivity}, backend::String, generate_field::Function)
    a::Field = generate_field()
    out = Field(Edge, zeros(Float64, 12))

    # Compute the ground truth manually computing the minimum of the value of each neighbor
    expected_output = compute_expected_output_comparing_values(offset_provider, a, minimum)

    @field_operator function fo_min_over(a::Field{Tuple{Cell_},Float64})::Field{Tuple{Edge_},Float64}
        return min_over(a(E2C), axis=E2CDim)
    end

    fo_min_over(a, offset_provider=offset_provider, backend=backend, out=out)
    @test out == expected_output
end

function test_fo_simple_broadcast(backend::String)
    data = collect(1.0:15.0)
    broadcast_num_dims = 5
    a = Field(Cell, data)
    out = Field((Cell, K), zeros(15, broadcast_num_dims))

    # Compute the expected output by broadcasting a
    expected_output = [a[i] for i in 1:15, j in 1:broadcast_num_dims]

    @field_operator function fo_simple_broadcast(a::Field{Tuple{Cell_},Float64})::Field{Tuple{Cell_,K_},Float64}
        return broadcast(a, (Cell, K))
    end

    fo_simple_broadcast(a, backend=backend, out=out)
    @test out == expected_output
end

function test_fo_scalar_broadcast(backend::String)
    out = Field((Cell, K), fill(0.0, (10, 10)))

    # Compute the expected output by broadcasting the value
    expected_output = fill(5.0, (10, 10))

    @field_operator function fo_scalar_broadcast()::Field{Tuple{Cell_,K_},Float64}
        return broadcast(5.0, (Cell, K))
    end

    fo_scalar_broadcast(backend=backend, out=out)
    @test out == expected_output
end

function test_fo_where(backend::String)
    a = Field((Cell, K), reshape(collect(1.0:10.0), (5, 2))) # The matrix is filled column major
    b = Field((Cell, K), fill(-1.0, (5, 2)))
    mask = Field((Cell, K), [true  false; 
                             false true; 
                             true  false; 
                             false false; 
                             true  true  ])
    out = Field((Cell, K), zeros(5, 2))

    expected_output =  [ 1 -1
                        -1  7
                         3 -1
                        -1 -1
                         5 10 ]

    @field_operator function fo_where(mask::Field{Tuple{Cell_,K_},Bool}, a::Field{Tuple{Cell_,K_},Float64}, b::Field{Tuple{Cell_,K_},Float64})::Field{Tuple{Cell_,K_},Float64}
        return where(mask, a, b)
    end

    fo_where(mask, a, b, backend=backend, out=out)
    @test out == expected_output 
end

function test_fo_astype(backend::String)
    a = Field((Cell, K), reshape(collect(1.0:12.0), (6, 2))) # Floating Point
    out = Field((Cell, K), zeros(Int64, (6, 2)))

    expected_values = reshape(collect(1.0:12.0), (6, 2))

    @field_operator function fo_astype(a::Field{Tuple{Cell_,K_},Float64})::Field{Tuple{Cell_,K_},Int64}
        return convert(Int64, a) # Integer
    end

    fo_astype(a, backend=backend, out=out)
    @test out == expected_values
    @test eltype(out.data) == Int64
    @test eltype(a.data) == Float64
end

function test_fo_sin(backend::String)
    a = Field((Cell, K), reshape(collect(1.0:12.0), (6, 2)))
    out = Field((Cell, K), zeros((6, 2)))

    # Compute the expected output using the sin function
    expected_output = sin.(reshape(collect(1.0:12.0), (6, 2)))

    @field_operator function fo_sin(a::Field{Tuple{Cell_,K_},Float64})::Field{Tuple{Cell_,K_},Float64}
        return sin.(a)
    end

    fo_sin(a, backend=backend, out=out)
    @test isapprox(out.data, expected_output, atol=1e-6)
end

function test_fo_asinh(backend::String)
    a = Field((Cell, K), reshape(collect(1.0:12.0), (6, 2)))
    out = Field((Cell, K), zeros((6, 2)))

    # Compute the expected output using the asinh function
    expected_output = asinh.(reshape(collect(1.0:12.0), (6, 2)))

    @field_operator function fo_asinh(a::Field{Tuple{Cell_,K_},Float64})::Field{Tuple{Cell_,K_},Float64}
        return asinh.(a)
    end

    fo_asinh(a, backend=backend, out=out)
    @test isapprox(out.data, expected_output, atol=1e-6)
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
    out = Field(Cell, zeros(15))

    # Compute the Ground Truth
    intermediate_result = a.data .+ b.data
    expected_output = intermediate_result .+ a.data

    @field_operator function fo_addition(a::Field{Tuple{Cell_},Float64}, b::Field{Tuple{Cell_},Float64})::Field{Tuple{Cell_},Float64}
        return a .+ b
    end

    @field_operator function nested_fo(a::Field{Tuple{Cell_},Float64}, b::Field{Tuple{Cell_},Float64})::Field{Tuple{Cell_},Float64}
        res = fo_addition(a, b)
        return res .+ a
    end

    nested_fo(a, b, backend=backend, out=out)

    # Test against the Ground Truth
    @test out.data == expected_output
end

function test_lap(offset_provider::Dict{String, Dimension}, backend::String, domain_generator::Function, debug::Bool=false)
    in_field = domain_generator()
    x_length, y_length = size(in_field.data)
    out_field = Field((IDim, JDim), zeros(Float64, x_length, y_length))
    expected_out = lap_ground_truth(in_field.data)
    
    @field_operator function lap(in_field::Field{Tuple{IDim_, JDim_}, Float64})
        return -4.0*in_field +
            in_field(Ioff[1]) +
            in_field(Ioff[-1]) +
            in_field(Joff[1]) +
            in_field(Joff[-1])
    end

    lap(in_field, offset_provider=offset_provider, backend=backend, out=out_field)
    
    if debug
        println("\nOutput Matrix after applying lap() operator in the field operator:")
        pretty_print_matrix(out_field.data)

        println("\nExpected ground truth of laplacian computation without field operator:")
        pretty_print_matrix(expected_out)
    end

    @test out_field.data[2:end-1, 2:end-1] == expected_out[2:end-1, 2:end-1]
    # TODO: add in the future the test for the border values
end

function test_lap_lap(offset_provider::Dict{String, Dimension}, backend::String, domain_generator::Function, debug::Bool=false)
    in_field = domain_generator()
    x_length, y_length = size(in_field.data)
    out_field = Field((IDim, JDim), zeros(Float64, x_length, y_length))
    expected_out = lap_lap_ground_truth(in_field.data)

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

    lap_lap(in_field, offset_provider=offset_provider, backend=backend, out=out_field)

    if debug
        println("\nOutput Matrix after applying lap(lap()) operator:")
        pretty_print_matrix(out_field.data)

        println("\nExpected ground truth of lap(lap()) computation without field operator:")
        pretty_print_matrix(expected_out)
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
    # testwrapper(setup_constant_cartesian_domain, test_lap, "embedded", constant_cartesian_domain)
    testwrapper(setup_constant_cartesian_domain, test_lap, "py", constant_cartesian_domain)

    # testwrapper(setup_constant_cartesian_domain, test_lap, "embedded", simple_cartesian_domain)
    testwrapper(setup_constant_cartesian_domain, test_lap, "py", simple_cartesian_domain)

    # testwrapper(setup_constant_cartesian_domain, test_lap_lap, "embedded", constant_cartesian_domain)
    testwrapper(setup_constant_cartesian_domain, test_lap_lap, "py", constant_cartesian_domain)
    
    # testwrapper(setup_constant_cartesian_domain, test_lap_lap, "embedded", simple_cartesian_domain)
    testwrapper(setup_constant_cartesian_domain, test_lap_lap, "py", simple_cartesian_domain)
end

@testset "Testset GT2Py fo exec" test_gt4py_fo_exec()
