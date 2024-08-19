using BenchmarkTools
using Statistics
using GridTools
using GridTools.ExampleMeshes.Unstructured
using GridTools.ExampleMeshes.Cartesian

include("../advection/advection_miniapp.jl")

# Advection Benchmarks 

advection_suite = BenchmarkGroup()
advection_suite["advection"]["upwind_julia_embedded"] = @benchmarkable upwind_scheme(
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
        # embedded backend
    )

# advection_suite["advection"]["upwind_python_backend"] = @benchmarkable upwind_scheme(
#         state.rho,
#         δt,
#         mesh.vol,
#         metric.gac,
#         state.vel[1],
#         state.vel[2],
#         state.vel[3],
#         mesh.pole_edge_mask,
#         mesh.dual_face_orientation,
#         mesh.dual_face_normal_weighted_x,
#         mesh.dual_face_normal_weighted_y,
#         out = state_next.rho,
#         offset_provider = mesh.offset_provider,
#         backend = "py"
#     )

advection_suite["advection"]["mpdata_program_julia_embedded"] = @benchmarkable mpdata_program(
        state.rho,
        δt,
        ϵ,
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

# TODO: disabled because the backend is not currently supporting it (the backend is too slow)
# advection_suite["advection"]["mpdata_program_python_backend"] = @benchmarkable mpdata_program(
#         state.rho,
#         δt,
#         ϵ,
#         mesh.vol,
#         metric.gac,
#         state.vel[1],
#         state.vel[2],
#         state.vel[3],
#         mesh.pole_edge_mask,
#         mesh.dual_face_orientation,
#         mesh.dual_face_normal_weighted_x,
#         mesh.dual_face_normal_weighted_y,
#         out = state_next.rho,
#         offset_provider = mesh.offset_provider,
#         backend = "py"
#     )

# Run the benchmark suite
println("Running the advection suite...")
advection_results = run(advection_suite)

upwind_embedded_results = advection_results["advection"]["upwind_julia_embedded"]
# upwind_python_backend_results = results["advection"]["upwind_python_backend"]
mpdata_embedded_results = advection_results["advection"]["mpdata_program_julia_embedded"]
# mpdata_python_backend_results = results["advection"]["mpdata_program_python_backend"]

# Function to convert nanoseconds to milliseconds for clearer output
ns_to_ms(time_ns) = time_ns / 1e6

println("Upwind scheme julia (embedded):")
println("\tTime taken: $(ns_to_ms(median(upwind_embedded_results.times))) ms\n")

# println("Upwind scheme julia (python backend):")
# println("\tTime taken: $(ns_to_ms(median(upwind_python_backend_results.times))) ms\n")

println("Mpdata program julia (embedded):")
println("\tTime taken: $(ns_to_ms(median(mpdata_embedded_results.times))) ms\n")

# println("Mpdata program julia (python backend):")
# println("\tTime taken: $(ns_to_ms(median(mpdata_python_backend_results.times))) ms\n")
