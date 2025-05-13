#!/bin/bash

test_dir="testing_code"
output_dir="output_files"

if [[ ! -d "$test_dir" ]]; then
    echo "Error: $test_dir does not exist."
    exit 1
fi

if [[ ! -d "$output_dir" ]]; then
    mkdir $output_dir
fi

echo "Compiling Parser..."
make

for file in "$test_dir"/*; do
    if [[ -f "$file" ]]; then
        echo "Parsing $file..."
        echo
        echo "Parser Output:"
        echo

        base=$(basename $file .py)

        ./parse < "$file"
        if [[ $? -ne 0 ]]; then
            echo "Compiler Errors. Continuing..."
            echo
            continue
        fi

        ./parse < "$file" > "$output_dir/${base}.c"

        echo
        echo "Output From Running C File:"
        echo

        gcc $output_dir/$base.c -o $output_dir/$base
        ./$output_dir/$base

        echo
        echo "-------------------------------"
        echo
    fi
done
