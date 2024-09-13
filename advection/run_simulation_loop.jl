# Run Advection Miniapp Simulation
# This script demonstrates an advection simulation using the Atlas library.

include("visualization_utils.jl")
include("advection_setup.jl")

const global VISUALIZATION_FLAG::Bool=false
const global VERBOSE_FLAG::Bool=true

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
