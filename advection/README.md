### README for Running `advection_setup.jl` using `run_simulation_loop.jl`

This README provides instructions on how to run the `run_simulation_loop.jl` script for simulating advection using the Atlas library. The script allows for terminal visualization, which can be enabled as described below.

#### Prerequisites

1. **Python Environment and Atlas4py Installation**:
   - Ensure that your Python environment is activated.
     ```sh
     source .venv/bin/activate # Ignore if the env is already activated
     ```
   - Install the `atlas4py` package using the following command:
     ```sh
     pip install -i https://test.pypi.org/simple/ atlas4py
     ```

2. **Enabling Visualization** (optional):
   - The script has a `VISUALIZATION_FLAG` that can be set to enable or disable visualization on the terminal. Ensure that this flag is set to `true` in the `run_simulation_loop.jl` script if you wish to enable visualization.
   - Note: Other parameters such as the number of iterations can be changed in the `# Simulation Parameters` section of the `advection_setup.jl` script.

#### Running the Simulation

1. **Running the Script**:
   - Use the following command to run the `run_simulation_loop.jl` script with Julia:
     ```sh
     julia --color=yes --project=$GRIDTOOLS_JL_PATH/GridTools.jl $GRIDTOOLS_JL_PATH/GridTools.jl/src/examples/advection/run_simulation_loop.jl
     ```

#### Example

Here is an example of how to set the `VISUALIZATION_FLAG` in the `run_simulation_loop.jl` script and run the simulation:

1. **Setting the Visualization Flag**:
   - Open the `run_simulation_loop.jl` script.
   - Set the `VISUALIZATION_FLAG` to `true`:
     ```julia
     const VISUALIZATION_FLAG = true
     ```

2. **Running the Simulation**:
   - Open your terminal.
   - Run the script with the following command:
     ```sh
     export GRIDTOOLS_JL_PATH=...
     julia --color=yes --project=. $GRIDTOOLS_JL_PATH/src/examples/advection/run_simulation_loop.jl
     ```

By following these steps, you should be able to run the `run_simulation_loop.jl` script and visualize the advection simulation results on your terminal.
