
"""
    precompute_mapping(mesh, xlim, ylim, grid_size)

Precomputes the nearest vertex mapping for a structured grid.

# Arguments
- `mesh::Mesh`: An object containing the unstructured mesh data. It should have a property `xyarc` which is a matrix where each row represents the coordinates of a vertex.
- `xlim::Tuple{Float64, Float64}`: A tuple `(x_min, x_max)` defining the range of x coordinates for the structured grid.
- `ylim::Tuple{Float64, Float64}`: A tuple `(y_min, y_max)` defining the range of y coordinates for the structured grid.
- `grid_size::Int`: The size of the structured grid (number of points along each axis).

# Returns
- `mapping::Matrix{Int}`: A matrix of size `(grid_size, grid_size)` where each element contains the index of the nearest vertex in the unstructured mesh for the corresponding point on the structured grid.
"""
function precompute_mapping(mesh, xlim, ylim, grid_size)
    x_range = range(xlim[1], stop=xlim[2], length=grid_size)
    y_range = range(ylim[1], stop=ylim[2], length=grid_size)
    mapping = fill(0, grid_size, grid_size)

    for i in 1:grid_size
        for j in 1:grid_size
            x = x_range[i]
            y = y_range[j]
            # Find the nearest vertex in the unstructured mesh
            distances = [(mesh.xyarc[v, 1] - x)^2 + (mesh.xyarc[v, 2] - y)^2 for v in 1:size(mesh.xyarc, 1)]
            nearest_vertex = argmin(distances)
            mapping[i, j] = nearest_vertex
        end
    end

    return mapping
end

"""
    matrix_to_ascii(matrix::Matrix{Float64})::String

Converts a matrix of `Float64` values to an ASCII art representation.

# Arguments
- `matrix::Matrix{Float64}`: A 2D array of `Float64` values representing the data to be converted to ASCII art.

# Returns
- `ascii_art::String`: A string containing the ASCII art representation of the matrix.
"""
function matrix_to_ascii(matrix::Matrix{Float64})
    ascii_art = ""
    chars = [' ', '.', ':', '-', '=', '+', '*', '#', '%', '@']
    min_val = minimum(matrix)
    max_val = maximum(matrix)
    range_val = max_val - min_val

    for row in eachrow(matrix)
        for value in row
            index = Int(floor((value - min_val) / range_val * (length(chars) - 1))) + 1
            ascii_art *= chars[index]
        end
        ascii_art *= '\n'
    end

    return ascii_art
end

"""
    print_state_ascii(state, mesh, mapping, timestep, grid_size=50)

Prints the current state of a simulation as ASCII art.

# Arguments
- `state`: An object containing the simulation state. It should have a property `rho` with a nested property `data` which is an array of values representing the state.
- `mesh::Mesh`: An object containing the unstructured mesh data. Used for mapping the state to grid points.
- `mapping::Matrix{Int}`: A matrix mapping structured grid points to the nearest vertex in the unstructured mesh, as computed by the `precompute_mapping` function.
- `timestep::Int`: An integer representing the current time step of the simulation.
- `grid_size::Int`: (Optional) The size of the structured grid. Default is 50.

# Returns
- `Nothing`
- This function clears the terminal and prints the ASCII art representation of the current state.
"""
function print_state_ascii(state, mesh, mapping, timestep, grid_size=50)
    # Clear the terminal
    print("\033c")

    println("Timestep $timestep")
    grid_data = zeros(Float64, grid_size, grid_size)

    for i in 1:grid_size
        for j in 1:grid_size
            grid_data[i, j] = state.rho.data[mapping[i, j]]
        end
    end

    ascii_art = matrix_to_ascii(grid_data)
    println(ascii_art)
end
