# GridTools

[![Build Status](https://github.com/jeffzwe/GridTools.jl/actions/workflows/CI.yml/badge.svg?branch=main)](https://github.com/jeffzwe/GridTools.jl/actions/workflows/CI.yml?query=branch%3Amain) [![Static Badge](https://img.shields.io/badge/docs-stable-blue.svg)](https://jeffzwe.github.io/GridTools.jl/dev)

## Installation

### Development Installation

As of August 2024, the recommended Python version for development is **3.10.14**.

**Important Note:** The Python virtual environment must be created in the directory specified by `GRIDTOOLS_JL_PATH/.venv`. Creating the environment in any other location will result in errors.

#### Steps to Set Up the Development Environment

1. **Set Environment Variables:**
   Set the environment variables for `GRIDTOOLS_JL_PATH` and `GT4PY_PATH`. Replace `...` with the appropriate paths on your system.

   ```bash
   export GRIDTOOLS_JL_PATH="..."
   export GT4PY_PATH="..."
   ```

2. **Create a Python Virtual Environment:**
   Navigate to the `GRIDTOOLS_JL_PATH` directory and create a Python virtual environment named `.venv`. Ensure you are using a compatible Python version (i.e. 3.10.14).

   ```bash
   cd $GRIDTOOLS_JL_PATH
   python3.10 -m venv .venv
   ```

3. **Activate the Virtual Environment:**
   Activate the virtual environment. You need to run this command every time you work with GridTools.jl.

   ```bash
   source .venv/bin/activate
   ```

4. **Clone the GT4Py Repository:**
   Clone the GT4Py repository. You can use the specific branch mentioned or the main repository as needed.

   ```bash
   git clone --branch fix_python_interp_path_in_cmake git@github.com:tehrengruber/gt4py.git
   # Alternatively, you can clone the main repository:
   # git clone git@github.com:GridTools/gt4py.git $GT4PY_PATH
   ```

5. **Install Required Packages:**
   Install the development requirements and the GT4Py package in editable mode.

   ```bash
   pip install -r $GT4PY_PATH/requirements-dev.txt
   pip install -e $GT4PY_PATH
   ```

6. **Build PyCall:**
   With the virtual environment activated, run Julia form the `GridTools.jl` folder with the command `julia --project=.` and then build using the following commands:

   ```julia
   using Pkg
   Pkg.build()
   ```

## Troubleshooting

### Common Build Errors

__undefined symbol: PyObject_Vectorcall__
- Make sure to run everything in the same environment that you built `PyCall` with. A common reason for this error is that PyCall was built in a virtual environment and then was not loaded when executing stencils.

__CMake Error: Could NOT find Boost__
- GridTools.jl requires the Boost library version 1.65.1 or higher. If Boost is not installed, you can install it via your system's package manager. For example, on Ubuntu, use:
  ```bash
  sudo apt-get install libboost-all-dev
  ```
    Make sure the installed version meets the minimum required version of 1.65.1. If CMake still cannot find Boost after installation, you may need to manually specify the Boost installation path in the CMake command using the `-DBOOST_ROOT=/path/to/boost` option, where `/path/to/boost` is the directory where Boost is installed.

__Supporting GPU Backend with CUDA__

- To enable GPU acceleration and utilize the GPU backend features of this project, it is essential to have the NVIDIA CUDA Toolkit installed. CUDA provides the necessary compiler (nvcc) and libraries for developing and running applications that leverage NVIDIA GPUs.

- If the `LD_LIBRARY_PATH` environment variable is set in your current environment, it is recommended to unset it. This avoids conflicts between the paths managed by CUDA.jl and those already present on the system.
    ```julia
    julia> using CUDA
    ┌ Warning: CUDA runtime library `...` was loaded from a system path, `/usr/local/cuda/lib64/...`.
    │ 
    │ This may cause errors. Ensure that you have not set the LD_LIBRARY_PATH
    │ environment variable, or that it does not contain paths to CUDA libraries.
    ```
