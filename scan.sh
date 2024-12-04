#!/bin/bash

# Script to scan container images in a Helm chart using Grype Docker container
# Outputs scan results in a CSV file, including only vulnerabilities with a severity of Medium or higher.

set -euo pipefail

# Check if necessary tools are installed
check_dependencies() {
    for cmd in docker helm jq; do
        if ! command -v $cmd &>/dev/null; then
            echo "Error: $cmd is not installed. Please install it and try again."
            exit 1
        fi
    done
}

# Extract images from a Helm chart
extract_images() {
    local chart_dir=$1
    # echo "Extracting container images from Helm chart in: $chart_dir"
    helm template "$chart_dir" | grep -E 'image: ' | awk '{print $2}' | tr -d '"' | sort | uniq
}

# Scan a single image using Grype Docker container
scan_with_grype() {
    local image=$1
    local output=$2
    echo "Scanning image with Grype: $image"
    docker run --rm -v /var/run/docker.sock:/var/run/docker.sock anchore/grype $image -o json > "$output"
}

# Convert JSON results to CSV using jq, including only vulnerabilities of Medium or higher severity
convert_to_csv() {
    local grype_json=$1
    local image=$2
    local csv_file=$3

    # Extract Grype results and filter for Medium or higher severity
    jq -r --arg image "$image" '
        .matches[] |
        select(.vulnerability.severity == "High" or .vulnerability.severity == "Critical" or .vulnerability.severity == "Medium") |
        [$image, .artifact.name, .vulnerability.id, .vulnerability.severity] |
        @csv
    ' "$grype_json" >> "$csv_file"
}

# Main function
main() {
    check_dependencies

    chart_dir=$1

    if [[ ! -d $chart_dir ]]; then
        echo "Error: Directory $chart_dir does not exist."
        exit 1
    fi

    # CSV file to store results
    output_csv="scan_results.csv"
    echo "image:tag,component/library,vulnerability,severity" > "$output_csv"

    # Temporary file for Grype scan results
    grype_results=$(mktemp)

    # Extract images
    images=$(extract_images "$chart_dir")

    for image in $images; do
        echo "Processing image: $image"
        
        scan_with_grype "$image" "$grype_results"
        convert_to_csv "$grype_results" "$image" "$output_csv"
    
    done

    # Cleanup
    rm -f "$grype_results"

    echo "All scans complete. Results saved to $output_csv."
}

main "$@"
