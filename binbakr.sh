#!/bin/bash

# Array of binary names
binaries=("vi")

#help flag => display help menu
if [[ "$1" == "-h" ]]; then
    echo "Usage: $0 <targetDirectory>"
    exit 0
fi

#initialize target directory
if [[ -z "$1" ]]; then
    echo "Error: No target directory given"
    echo "Usage: $0 <targetDirectory>"
    exit 0
else
    targetDirectory="$1"
fi

#check if target directory exists
if [[ ! -d "$targetDirectory" ]]; then
    echo "Error: Invalid target directory at $targetDirectory"
    exit 0
fi

# copy operation
for binary in "${binaries[@]}"; do
    binaryPath=$(which "$binary")
    
    #check if binary exists
    if [[ -z "$binaryPath" ]]; then
        echo "Warning: $binary not found, skipping"
    # check if binary is already in the target location
    elif [[ -f "$targetDirectory/$binary" ]]; then
        echo "Warning: $binary already exists in $targetDirectory, skipped with no backup"
    # otherwise, shouldn't be any errors, begin copy
    else
        cp "$binaryPath" "$targetDirectory"
        # error checking, if there was an error copying, exit
        if [[ ! -f "$targetDirectory/$binary" ]]; then
            echo "Error: Failed to copy $binary to $targetDirectory"
            exit 1
        else
            echo "Success: Copied $binary to $targetDirectory"
        fi
    fi
done