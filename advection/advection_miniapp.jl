# Advection Miniapp
# This script demonstrates an advection simulation using the Atlas library.

using Printf
using Debugger
using Statistics
using Profile
using GridTools
using GridTools.ExampleMeshes.Unstructured

const global VISUALIZATION_FLAG::Bool=false
const global VERBOSE_FLAG::Bool=true

# Include additional necessary files for mesh, state container, metric calculations, and advection operations
include("../src/atlas/atlas_mesh.jl")
include("state_container.jl")
include("metric.jl")
include("advection.jl")
include("visualization_utils.jl")

# Grid and Mesh Initialization --------------------------------------------------------------------------------
# Create a structured grid and mesh for the simulation
grid = atlas.StructuredGrid("O50")
mesh = AtlasMesh(grid, num_level = 30)

# Simulation Parameters ---------------------------------------------------------------------------------------
δt = 1800.0  # time step in s
niter = 50
ϵ = 1.0e-8

# Calculate metric properties from the mesh
metric = m_from_mesh(mesh)

# Define the spatial extent of the mesh
origin = minimum(mesh.xyarc, dims = 1)
extent = maximum(mesh.xyarc, dims = 1) .- minimum(mesh.xyarc, dims = 1)
xlim = (minimum(mesh.xyarc[:, 1]), maximum(mesh.xyarc[:, 1]))
ylim = (minimum(mesh.xyarc[:, 2]), maximum(mesh.xyarc[:, 2]))

# Get dimensions of various elements in the mesh
vertex_dim = getproperty(mesh, DIMENSION_TO_SIZE_ATTR[Vertex])
k_dim = getproperty(mesh, DIMENSION_TO_SIZE_ATTR[K])
edge_dim = getproperty(mesh, DIMENSION_TO_SIZE_ATTR[Edge])

# Define vertical level indices
level_indices = Field(K, zeros(Int, k_dim))
level_indices .= collect(0:mesh.num_level-1)

# Initialize state containers for the current and next states
state = sc_from_mesh(mesh)
state_next = sc_from_mesh(mesh)

# Temporary Fields Initialization -----------------------------------------------------------------------------
# Create temporary fields used in the computation
tmp_fields = Dict{String, Field}()
for i = 1:6
    tmp_fields[@sprintf("tmp_vertex_%d", i)] = Field((Vertex, K), zeros(vertex_dim, k_dim))
end
for j = 1:3
    tmp_fields[@sprintf("tmp_edge_%d", j)] = Field((Edge, K), zeros(edge_dim, k_dim))
end

# Initial Conditions -------------------------------------------------------------------------------------------
# Define the initial conditions for the scalar field (rho) using a field operator
@field_operator function initial_rho(
    mesh_radius::Float64,
    mesh_xydeg_x::Field{Tuple{Vertex_}, Float64},
    mesh_xydeg_y::Field{Tuple{Vertex_}, Float64},
    mesh_vertex_ghost_mask::Field{Tuple{Vertex_}, Bool}
)::Field{Tuple{Vertex_, K_}, Float64}
    # Define constants for the initial condition
    lonc = 0.5 * pi
    latc = 0.0
    _deg2rad = 2.0 * pi / 360.0

    # Convert mesh coordinates from degrees to radians
    mesh_xyrad_x, mesh_xyrad_y = mesh_xydeg_x .* _deg2rad, mesh_xydeg_y .* _deg2rad
    rsina, rcosa = sin.(mesh_xyrad_y), cos.(mesh_xyrad_y)

    # Compute the distance from the center point (lonc, latc)
    zdist =
        mesh_radius .*
        acos.(sin(latc) .* rsina .+ cos(latc) .* rcosa .* cos.(mesh_xyrad_x .- lonc))

    # Calculate the radial profile
    rpr = (zdist ./ (mesh_radius / 2.0)) .^ 2.0
    rpr = min.(1.0, rpr)

    # Return the initial scalar field values, setting ghost cells to zero
    return broadcast(
        where(mesh_vertex_ghost_mask, 0.0, 0.5 .* (1.0 .+ cos.(pi .* rpr))),
        (Vertex, K)
    )
end

# Initialize the scalar field (rho) using the initial_rho function
initial_rho(
    mesh.radius,
    mesh.xydeg_x,
    mesh.xydeg_y,
    mesh.vertex_ghost_mask,
    out = state.rho,
    offset_provider = mesh.offset_provider
)

# Define the initial conditions for the velocity field using a field operator
@field_operator function initial_velocity(
    mesh_xydeg_x::Field{Tuple{Vertex_}, Float64},
    mesh_xydeg_y::Field{Tuple{Vertex_}, Float64},
    metric_gac::Field{Tuple{Vertex_}, Float64},
    metric_g11::Field{Tuple{Vertex_}, Float64},
    metric_g22::Field{Tuple{Vertex_}, Float64}
)::Tuple{
    Field{Tuple{Vertex_, K_}, Float64},
    Field{Tuple{Vertex_, K_}, Float64},
    Field{Tuple{Vertex_, K_}, Float64}
}
    # Convert mesh coordinates from degrees to radians
    _deg2rad = 2.0 * pi / 360.0
    mesh_xyrad_x, mesh_xyrad_y = mesh_xydeg_x .* _deg2rad, mesh_xydeg_y .* _deg2rad

    # Set initial velocity parameters
    u0 = 22.238985328911745
    flow_angle = 0.0 * _deg2rad  # radians

    # Calculate sine and cosine of mesh coordinates and flow angle
    rsina, rcosa = sin.(mesh_xyrad_y), cos.(mesh_xyrad_y)
    cosb, sinb = cos(flow_angle), sin(flow_angle)

    # Compute velocity components
    uvel_x = u0 .* (cosb .* rcosa .+ rsina .* cos.(mesh_xyrad_x) .* sinb)
    uvel_y = -u0 .* sin.(mesh_xyrad_x) .* sinb

    # Broadcast velocity components across the mesh
    vel_x = broadcast(uvel_x .* metric_g11 .* metric_gac, (Vertex, K))
    vel_y = broadcast(uvel_y .* metric_g22 .* metric_gac, (Vertex, K))
    vel_z = broadcast(0.0, (Vertex, K))

    return vel_x, vel_y, vel_z
end

# Initialize the velocity field
initial_velocity(
    mesh.xydeg_x,
    mesh.xydeg_y,
    metric.gac,
    metric.g11,
    metric.g22,
    out = state.vel,
    offset_provider = mesh.offset_provider,
)

# Copy the initial velocity field to the next state
copyfield!(state_next.vel, state.vel)

# Example of printing initial rho statistics (commented out)
# println("min max avg of initial rho = $(minimum(state.rho.data)) , $(maximum(state.rho.data)) , $(mean(state.rho.data))")

# Initialize a temporary field with vertical levels for use in the simulation
tmp_fields["tmp_vertex_1"] .= reshape(collect(0.0:mesh.num_level-1), (1, mesh.num_level))
nabla_z(
    tmp_fields["tmp_vertex_1"],
    level_indices,
    mesh.num_level,
    out = tmp_fields["tmp_vertex_2"],
    offset_provider = mesh.offset_provider
)

if VISUALIZATION_FLAG
    # Precompute the mapping between the unstructured domain to the structured one for ASCII art visualization
    grid_size = 50
    mapping = precompute_mapping(mesh, xlim, ylim, grid_size)
end

# Main Simulation Loop ----------------------------------------------------------------------------------------
for i = 1:niter
    # Perform the upwind advection scheme to update the scalar field (rho)
    upwind_scheme(
        state.rho,
        δt,
        mesh.vol,
        metric.gac,
        state.vel[1],
        state.vel[2],
        state.vel[3],
        mesh.pole_edge_mask,
        mesh.dual_face_orientation,
        mesh.dual_face_normal_weighted_x,
        mesh.dual_face_normal_weighted_y,
        out = state_next.rho,
        offset_provider = mesh.offset_provider
    )

    # Print the current timestep
    if VERBOSE_FLAG
        println("Timestep $i")
    end

    if VISUALIZATION_FLAG
        # Print the current state as ASCII art every 5 timesteps
        print_state_ascii(state, mesh, mapping, i, grid_size)
    end

    # TODO: make a function out of this switch
    # Swap the current and next state
    temp = state
    global state = state_next
    global state_next = temp

    # Update the periodic boundary layers
    update_periodic_layers(mesh, state.rho)
end

if VERBOSE_FLAG
    # Output the final statistics for the scalar field (rho) and velocity fields
    println(
        "min max sum of final rho = $(minimum(state.rho.data)) , $(maximum(state.rho.data)) , $(sum(state.rho.data))"
    )
    println("Final Vel0 sum after $niter iterations: $(sum(state.vel[1].data))")
    println("Final Vel1 sum after $niter iterations: $(sum(state.vel[2].data))")
end
