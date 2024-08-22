#!/bin/bash

# This script automates the process of benchmarking recent changes by tagging
# the last two commits and running benchmarks using the AirspeedVelocity package.
# It supports conditional execution based on user input to include specific benchmarks
# for advection and allows dynamic configuration of execution threads.
#
# Usage:
#   ./autorun_benchmarks.sh [--advection] [--threads=NUM]
#     --advection: Optional. If specified, runs advection-specific benchmarks.
#     --threads=NUM: Optional. Specifies the number of threads to use. Default is 8.

# Default number of threads
threads=8

# Function to display usage
usage() {
    echo "Usage: $0 [--advection] [--threads=NUM]"
    echo "  --advection: Run the advection comparison with specific benchmark script."
    echo "  --threads=NUM: Specify the number of threads (default is 8)."
    exit 1
}

# Parse command-line arguments
for arg in "$@"
do
    case $arg in
        --advection)
        advection=true
        shift # Remove --advection from processing
        ;;
        --threads=*)
        threads="${arg#*=}"
        shift # Remove --threads=NUM from processing
        ;;
        *)
        # Unknown option
        usage
        ;;
    esac
done

# Check if the tags already exist and delete them if they do
if git rev-parse -q --verify "refs/tags/after_debug" >/dev/null; then
    git tag -d after_debug
fi

if git rev-parse -q --verify "refs/tags/before_debug" >/dev/null; then
    git tag -d before_debug
fi

# Tag the last commit as 'after_debug'
git tag after_debug HEAD
echo "Tagged the latest commit as 'after_debug'"

# Tag the second last commit as 'before_debug'
git tag before_debug HEAD~1
echo -e "Tagged the previous commit as 'before_debug'\n"

# Print the before and after tags with their messages
git tag -n | grep -E 'before_debug|after_debug' | while IFS= read -r line; do echo "$line"; done ; echo ""

# Conditional command based on the --advection flag
if [ "$advection" == true ]; then
    # Set the benchmark script for advection
    benchmark_script="benchmark/benchmarks_advection.jl"
    command="benchpkg --rev=before_debug,after_debug \
             -s $benchmark_script \
             --bench-on=before_debug \
             --exeflags=\"--threads=$threads\""
else
    command="benchpkg --rev=before_debug,after_debug \
             --bench-on=before_debug \
             --exeflags=\"--threads=$threads\""
fi

# Print and execute the command
echo "Executing command: $command"
eval $command
