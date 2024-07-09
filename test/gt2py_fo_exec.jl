using Test
using GridTools
using MacroTools

include("mesh_definitions.jl")

struct TestFailedException <: Exception
    message::String
end

macro to_py(expr::Expr)
    res = quote try
            $(esc(expr))
            true
        catch e
            throw(TestFailedException("The following test: $($(string(namify(expr)))) encountered following error: $e"))
        end
    end
    return res
end

# ========================================
# ============== Utility =================
# ========================================

struct ConnectivityData
    edge_to_cell_table::Matrix{Integer}
    cell_to_edge_table::Matrix{Integer}
    E2C_offset_provider::Connectivity
    C2E_offset_provider::Connectivity
    offset_provider::Dict{String, Connectivity}
end

function testwrapper(setupfunc::Union{Function,Nothing}, testfunc::Function, args...)
    if setupfunc === nothing
        testfunc(args...)
    else
        data = setupfunc()
        testfunc(data, args...)
    end
end

# ========================================
# ============== Setup ===================
# ========================================

function setup_simple_connectivity()
    edge_to_cell_table = [
        [1  -1];
        [3  -1];
        [3  -1];
        [4  -1];
        [5  -1];
        [6  -1];
        [1  6];
        [1  2];
        [2  3];
        [2  4];
        [4  5];
        [5  6]
    ]

    cell_to_edge_table = [
        [1   7   8];
        [8   9  10];
        [2   3   9];
        [4  10  11];
        [5  11  12];
        [6   7  12]
    ]

    E2C_offset_provider = Connectivity(edge_to_cell_table, Cell, Edge, 2)
    C2E_offset_provider = Connectivity(cell_to_edge_table, Edge, Cell, 3)

    offset_provider = Dict{String, Connectivity}(
                    "E2C" => E2C_offset_provider,
                    "C2E" => C2E_offset_provider
                    )

    return ConnectivityData(edge_to_cell_table, cell_to_edge_table, E2C_offset_provider, C2E_offset_provider, offset_provider)
end

# ========================================
# ========= Tests Definition =============
# ========================================

function test_fo_addition(backend::String)
    a = Field(Cell, collect(1.:15.))
    b = Field(Cell, collect(-1.:-1:-15.))
    out = Field(Cell, zeros(Float64, 15))

    @field_operator function fo_addition(a::Field{Tuple{Cell_}, Float64}, b::Field{Tuple{Cell_}, Float64})::Field{Tuple{Cell_}, Float64}
        return a .+ b
    end

    fo_addition(a, b, backend = backend, out = out)
    @test all(out.data .== 0)
end

function test_fo_nested_if_else(backend::String)
    a = Field(Cell, collect(Int32, 1:15))  # TODO(tehrengruber): if we don't use the right dtype here we get a horrible error in python
    out = Field(Cell, zeros(Int32, 15))

    @field_operator function fo_nested_if_else(f::Field{Tuple{Cell_}, Int32})::Field{Tuple{Cell_}, Int32}
        tmp = f
        if 1. < 10.0
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

    fo_nested_if_else(a, backend = backend, out = out)
    @test all(out.data .== collect(22:36))
end

function test_fo_remapping(data::ConnectivityData, backend::String)
    a = Field(Cell, collect(1.:15.))
    out = Field(Edge, zeros(Float64, 12))
    expected_output = a[data.edge_to_cell_table[:, 1]] # First column of the edge to cell connectivity table

    @field_operator function fo_remapping(a::Field{Tuple{Cell_}, Float64})::Field{Tuple{Edge_}, Float64}
        return a(E2C[1])
    end

    fo_remapping(a, offset_provider = data.offset_provider, backend = backend, out = out)
    @test all(out.data .== expected_output)
end

function test_fo_neighbor_sum(backend::String)
    a = Field(Cell, collect(1.:15.))
    out = Field(Edge, zeros(Float64, 12))

    @field_operator function fo_neighbor_sum(a::Field{Tuple{Cell_}, Float64})::Field{Tuple{Edge_}, Float64}
        return neighbor_sum(a(E2C), axis=E2CDim)
    end

    @test @to_py fo_neighbor_sum(a, offset_provider=offset_provider, backend = "py", out = out)
end

function test_fo_max_over(backend::String)
    
end

function test_fo_min_over(backend::String)
    
end

function test_fo_simple_broadcast(backend::String)
    
end

function test_fo_scalar_broadcast(backend::String)
    
end

function test_fo_where(backend::String)
    
end

function test_fo_astype(backend::String)
    
end

function test_fo_sin(backend::String)
    
end

function test_fo_asinh(backend::String)
    
end

function test_fo_offset_array(backend::String)
    
end

function test_nested_fo(backend::String)
    
end

# ========================================
# ========== Test Executions =============
# ========================================

function test_gt4py_fo_exec()
    testwrapper(nothing, (args...) -> test_fo_addition(args...), "embedded")
    testwrapper(nothing, (args...) -> test_fo_addition(args...), "py")

    testwrapper(nothing, (args...) -> test_fo_nested_if_else(args...), "embedded")
    testwrapper(nothing, (args...) -> test_fo_nested_if_else(args...), "py")

    testwrapper(setup_simple_connectivity, (args...) -> test_fo_remapping(args...), "embedded")
    testwrapper(setup_simple_connectivity, (args...) -> test_fo_remapping(args...), "py")
end

function test_gt4py_fo_exec_legacy()
    # Set up locally to mimic the previous global behavior
    data = setup_simple_connectivity()
    offset_provider = data.offset_provider

    # ------------------------------------------------
    a = Field(Cell, collect(1.:15.))
    out = Field(Edge, zeros(Float64, 12))

    @field_operator function fo_neighbor_sum(a::Field{Tuple{Cell_}, Float64})::Field{Tuple{Edge_}, Float64}
        return neighbor_sum(a(E2C), axis=E2CDim)
    end

    @test @to_py fo_neighbor_sum(a, offset_provider=offset_provider, backend = "py", out = out)

    # ------------------------------------------------
    a = Field(Cell, collect(1.:15.))
    out = Field(Edge, zeros(Float64, 12))

    @field_operator function fo_max_over(a::Field{Tuple{Cell_}, Float64})::Field{Tuple{Edge_}, Float64}
        return max_over(a(E2C), axis=E2CDim)
    end

    @test @to_py fo_max_over(a, offset_provider=offset_provider, backend = "py", out = out)

    # ------------------------------------------------

    a = Field(Cell, collect(1.:15.))
    out = Field(Edge, zeros(Float64, 12))

    @field_operator function fo_min_over(a::Field{Tuple{Cell_}, Float64})::Field{Tuple{Edge_}, Float64}
        return min_over(a(E2C), axis=E2CDim)
    end

    @test @to_py fo_min_over(a, offset_provider=offset_provider, backend = "py", out = out)

    # ------------------------------------------------

    a = Field(Cell, collect(1.:15.))
    out = Field((Cell, K), zeros(15, 5))

    @field_operator function fo_simple_broadcast(a::Field{Tuple{Cell_}, Float64})::Field{Tuple{Cell_, K_}, Float64}
            return broadcast(a, (Cell, K))
    end
        
    @test @to_py fo_simple_broadcast(a, backend = "py", out = out)

    # ------------------------------------------------

    j_out = Field((), fill(0.), (Cell, K))
    py_out = Field((Cell, K), fill(0., (10, 10)))


    @field_operator function fo_scalar_broadcast()::Field{Tuple{Cell_, K_}, Float64}
        return broadcast(5., (Cell, K))
    end

    @test @to_py fo_scalar_broadcast(backend = "py", out = py_out)

    # ------------------------------------------------

    a = Field((Cell, K), reshape(collect(1.:12.), (6, 2)))
    b = Field((Cell, K), fill(-1., (6, 2)))
    mask = Field((Cell, K), rand(Bool, (6, 2)))
    out = Field((Cell, K), zeros(6, 2))

    @field_operator function fo_where(mask::Field{Tuple{Cell_, K_}, Bool}, a::Field{Tuple{Cell_, K_}, Float64}, b::Field{Tuple{Cell_, K_}, Float64})::Field{Tuple{Cell_, K_}, Float64}
            return where(mask, a, b)
    end

    @test @to_py fo_where(mask, a, b, backend = "py", out = out)

    # -------------------------------------------------

    a = Field((Cell, K), reshape(collect(1.:12.), (6, 2)))
    out = Field((Cell, K), zeros(Int64, (6, 2)))

    @field_operator function fo_astype(a::Field{Tuple{Cell_, K_}, Float64})::Field{Tuple{Cell_, K_}, Int64}
            return convert(Int64, a)
    end

    @test @to_py fo_astype(a, backend = "py", out = out)

    # -------------------------------------------------

    a = Field((Cell, K), reshape(collect(1.:12.), (6, 2)))
    out = Field((Cell, K), zeros((6, 2)))

    @field_operator function fo_sin(a::Field{Tuple{Cell_, K_}, Float64})::Field{Tuple{Cell_, K_}, Float64}
            return sin.(a)
    end

    @test @to_py fo_sin(a, backend = "py", out = out)

    # -------------------------------------------------

    a = Field((Cell, K), reshape(collect(1.:12.), (6, 2)))
    out = Field((Cell, K), zeros((6, 2)))

    @field_operator function fo_asinh(a::Field{Tuple{Cell_, K_}, Float64})::Field{Tuple{Cell_, K_}, Float64}
            return asinh.(a)
    end

    @test @to_py fo_asinh(a, backend = "py", out = out)

    # -------------------------------------------------

    # TODO OffsetArray is ignored for the moment

    A = Field((Vertex, K), reshape(collect(1.:15.), 3, 5), origin = Dict(Vertex => -2, K => -1))
    B = Field((K, Edge), reshape(ones(6), 3, 2))

    out = Field((Vertex, K, Edge), zeros(3,3,2))

    @field_operator function fo_offset_array(A::Field{Tuple{Vertex_, K_}, Float64}, B::Field{Tuple{K_, Edge_}, Float64})::Field{Tuple{Vertex_, K_, Edge_}, Float64}
            return A .+ B
        end

    @test @to_py fo_offset_array(A, B, backend="py", out=out)

    # -------------------------------------------------

    a = Field(Cell, collect(1.:15.))
    b = Field(Cell, ones(15))
    out = Field(Cell, zeros(15))

    @field_operator function fo_addition(a::Field{Tuple{Cell_}, Float64}, b::Field{Tuple{Cell_}, Float64})::Field{Tuple{Cell_}, Float64}
        return a .+ b
    end

    @field_operator function nested_fo(a::Field{Tuple{Cell_}, Float64}, b::Field{Tuple{Cell_}, Float64})::Field{Tuple{Cell_}, Float64}
        res = fo_addition(a, b)
        return res .+ a
    end
end

function run_all()
    test_gt4py_fo_exec()
    test_gt4py_fo_exec_legacy()
end

@testset "Testset GT2Py fo exec" run_all()
