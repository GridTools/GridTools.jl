#!/bin/bash

# Set the maximum number of attempts
max_attempts=10
attempt=0

# Check if a command is provided
if [ $# -eq 0 ]; then
    echo "Usage: $0 MY_BASH_COMMAND ARGS..."
    exit 1
fi

# Loop until the command succeeds or the maximum attempts are reached
while ! "$@"; do
    attempt=$((attempt + 1))
    if [ $attempt -ge $max_attempts ]; then
        echo "Command failed after $max_attempts attempts."
        exit 1
    fi
    echo "Attempt $attempt/$max_attempts failed. Retrying..."
done

echo "Command succeeded on attempt $attempt."