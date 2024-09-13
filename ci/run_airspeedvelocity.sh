#!/bin/bash

# Install and build the AirspeedVelocity package in Julia
echo "Installing and building AirspeedVelocity..."
julia -e 'using Pkg; Pkg.add("AirspeedVelocity"); Pkg.build("AirspeedVelocity")'

# Update the PATH to include the Julia binary directory
export PATH="$PATH:$HOME/.julia/bin"

# Optional: Print the updated PATH
echo "Updated PATH: $PATH"

# Create results directory
mkdir -p results

# Fetch the latest main branch
echo "Fetching the latest main branch..."
git fetch origin main:refs/remotes/origin/main

# Get the current commit and the last main commit
CURRENT_COMMIT=$(git rev-parse HEAD)
LAST_MAIN_COMMIT=$(git rev-parse origin/main)

# Benchmark the current commit against the last main commit
echo "Benchmarking current commit ($CURRENT_COMMIT) in the current branch and ($LAST_MAIN_COMMIT) in the main branch..."
benchpkg --rev="$LAST_MAIN_COMMIT,$CURRENT_COMMIT" --bench-on="$CURRENT_COMMIT" --output-dir=results/

# Create a benchmark table comparing the current commit against the last main commit
echo "Creating benchmark table comparing current commit ($CURRENT_COMMIT) against ($LAST_MAIN_COMMIT) in the main branch..."
benchpkgtable --rev="$LAST_MAIN_COMMIT,$CURRENT_COMMIT" --input-dir=results/ --ratio
