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

# Retrieve last two commit hashes
before_debug=$(git rev-parse HEAD~1)
after_debug=$(git rev-parse HEAD)

# Tag the last two commits if they are not already tagged
git tag -f after_debug $after_debug
git tag -f before_debug $before_debug

# Print the before and after tags with their messages
git tag -n | grep -E 'before_debug|after_debug' | while IFS= read -r line; do echo "$line"; done ; echo ""

# Conditional command based on the --advection flag
if [ "$advection" == true ]; then
    # Set the benchmark script for advection
    benchmark_script="benchmark/benchmarks_advection.jl"
    command="benchpkg --rev=$before_debug,$after_debug \
             -s $benchmark_script \
             --bench-on=$after_debug \
             --exeflags=\"--threads=$threads\""
else
    command="benchpkg --rev=$before_debug,$after_debug \
             --bench-on=$after_debug \
             --exeflags=\"--threads=$threads\""
fi

# Print and execute the command
echo "Executing command: $command"
eval $command
