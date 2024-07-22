# Benchmark Guide 🧭📈

## Installation

To install the benchmark CLI, execute the following command:

```bash
julia -e 'using Pkg; Pkg.add("AirspeedVelocity"); Pkg.build("AirspeedVelocity")'
```

This installation will create three executables in the `~/.julia/bin` folder: `benchpkg`, `benchpkgplot`, and `benchpkgtable`. It is necessary to add them to your `$PATH` to use them from any terminal session.

### Add to PATH Temporarily

To temporarily add the path to your session:

```bash
export PATH="$PATH:~/.julia/bin"
```

### Add to PATH Permanently

To permanently add the executables to your path, append the following line to your `.zshrc` or `.bashrc` file:

```bash
echo 'export PATH="$PATH:~/.julia/bin"' >> ~/.zshrc  # For zsh users
echo 'export PATH="$PATH:~/.julia/bin"' >> ~/.bashrc  # For bash users
```

## Running Benchmarks

To run benchmarks, simply execute the following command in the shell:

```bash
benchpkg
```

and it will:

1. Figure out the package name (from Project.toml)
2. Figure out the default branch name to compare the dirty state of your repo against
3. Evaluate all the benchmarks in benchmarks/benchmark.jl (BenchmarkTools.jl format – i.e., const SUITE = BenchmarkGroup())
4. Print the result in a nicely formatted markdown table

You can use the `--filter` option to quickly check if the load time has worsened compared to the master branch:

```bash
benchpkg --filter=time_to_load
```

The `benchpkg` was updated in June 2024 to automate the benchmark without specifying the parameters. 
To specify additional condition in `benchpkg` and to work with `benchpkgplot` consult the help command (`--h`).

## Creating New Benchmarks

TODO: Instructions for adding new benchmarks to the suite.
