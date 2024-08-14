# benchmark_mpdata.jl - Benchmarking for atlas advection code

using BenchmarkTools
using GridTools  # Assuming all necessary functionality like Field, Dimension are defined here
using Statistics
using Printf

Cell_ = Dimension{:Cell_, HORIZONTAL}
Edge_ = Dimension{:Edge_, HORIZONTAL}
Vertex_ = Dimension{:Vertex_, HORIZONTAL}
K_ = Dimension{:K_, VERTICAL}
V2VDim_ = Dimension{:V2V_, LOCAL}
V2EDim_ = Dimension{:V2E_, LOCAL}
E2VDim_ = Dimension{:E2V_, LOCAL}
Cell = Cell_()
K = K_()
Edge = Edge_()
Vertex = Vertex_()
V2VDim = V2VDim_()
V2EDim = V2EDim_()
E2VDim = E2VDim_()

V2V = FieldOffset("V2V", source = Vertex, target = (Vertex, V2VDim))
E2V = FieldOffset("E2V", source = Vertex, target = (Edge, E2VDim))
V2E = FieldOffset("V2E", source = Edge, target = (Vertex, V2EDim))
Koff = FieldOffset("Koff", source = K, target = K)

include("../src/atlas/atlas_mesh.jl")
include("../src/atlas/state_container.jl")
include("../src/atlas/metric.jl")
include("../src/atlas/advection.jl")

# Function to set up and run the benchmark
function benchmark_mpdata()
    # Set up the environment or load data
    grid = atlas.StructuredGrid("O50")
    mesh = AtlasMesh(grid, num_level = 30)

    # Define dimensions based on the mesh properties
    vertex_dim = getproperty(mesh, DIMENSION_TO_SIZE_ATTR[Vertex])
    k_dim = getproperty(mesh, DIMENSION_TO_SIZE_ATTR[K])
    edge_dim = getproperty(mesh, DIMENSION_TO_SIZE_ATTR[Edge])

    # Set parameters
    δt = 1800.0  # time step in s
    eps = 1.0e-8
    niter = 50  # Adjust based on how long you want the benchmark to run

    # Initialize fields and metrics
    state = sc_from_mesh(mesh)
    state_next = sc_from_mesh(mesh)
    tmp_fields = Dict{String, Field}()
    for i = 1:6
        tmp_fields[@sprintf("tmp_vertex_%d", i)] = Field((Vertex, K), zeros(vertex_dim, k_dim))
    end
    for j = 1:3
        tmp_fields[@sprintf("tmp_edge_%d", j)] = Field((Edge, K), zeros(edge_dim, k_dim))
    end

    # Benchmark the mpdata_program
    println("Starting the benchmark for mpdata_program...")
    bench_result = @benchmark begin
        mpdata_program(
            state.rho,
            δt,
            eps,
            mesh.vol,
            metric.gac,
            state.vel[1],
            state.vel[2],
            state.vel[3],
            mesh.pole_edge_mask,
            mesh.dual_face_orientation,
            mesh.dual_face_normal_weighted_x,
            mesh.dual_face_normal_weighted_y,
            tmp_fields["tmp_vertex_1"],
            tmp_fields["tmp_vertex_2"],
            tmp_fields["tmp_vertex_3"],
            tmp_fields["tmp_vertex_4"],
            tmp_fields["tmp_vertex_5"],
            tmp_fields["tmp_vertex_6"],
            tmp_fields["tmp_edge_1"],
            tmp_fields["tmp_edge_2"],
            tmp_fields["tmp_edge_3"]
        )
    end

    # Output benchmark results
    println("Benchmark completed.")
    display(bench_result)
end

# Run the benchmark function
benchmark_mpdata()
