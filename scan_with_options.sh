#!/bin/bash

# Script to scan container images in a specific version of a Helm chart and output vulnerability information.
# The script uses Grype or Trivy to scan the images and outputs results in a CSV format.

set -euo pipefail

# Function to check if necessary tools are installed
check_dependencies() {
    for cmd in docker helm jq; do
        if ! command -v $cmd &>/dev/null; then
            echo "Error: $cmd is not installed. Please install it and try again."
            exit 1
        fi
    done
}

# Extract images from a Helm chart, filtering out comments and non-image lines
extract_images() {
    local chart_dir=$1
    # Use helm template to extract images, filter lines that contain 'image:', remove extra spaces, and return only image names.
    helm template "$chart_dir" | grep -oP 'image:\s*\K\S+' | tr -d '"'  # This extracts only the image names following the 'image:' keyword
}

# Scan a single image using Grype Docker container
scan_with_grype() {
    local image=$1
    local output=$2
    echo "Scanning image with Grype: $image"
    docker run --rm -v /var/run/docker.sock:/var/run/docker.sock anchore/grype "$image" -o json > "$output"
}

# Scan a single image using Trivy Docker container
scan_with_trivy() {
    local image=$1
    local output=$2
    echo "Scanning image with Trivy: $image"
    docker run --rm -v /var/run/docker.sock:/var/run/docker.sock -v ./trivy/cache:/tmp/trivy aquasec/trivy --cache-dir /tmp/trivy/ image --format json --severity MEDIUM,CRITICAL "$image" > "$output"
}

# Convert JSON results to CSV using jq, including only vulnerabilities of Medium or higher severity
convert_to_csv() {
    local scanner=$1
    local scan_results=$2
    local image=$3
    local csv_file=$4

    if [[ "$scanner" == "grype" ]]; then
        jq -r --arg image "$image" '
            .matches[] |
            select(.vulnerability.severity == "High" or .vulnerability.severity == "Critical" or .vulnerability.severity == "Medium") |
            [$image, .artifact.name, .vulnerability.id, .vulnerability.severity] |
            @csv
        ' "$scan_results" >> "$csv_file"
    elif [[ "$scanner" == "trivy" ]]; then
        jq -r --arg image "$image" '
            .Results[] | .Vulnerabilities[] |
            select(.Severity == "MEDIUM" or .Severity == "CRITICAL" or .Severity == "HIGH") |
            [$image, .PkgName, .VulnerabilityID, .Severity] |
            @csv
        ' "$scan_results" >> "$csv_file" 2>$image-errors.txt || true
    fi
}

# Function to parse command-line arguments
parse_arguments() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            --repourl)
                repo_url="$2"
                shift 2
                ;;
            --reponame)
                repo_name="$2"
                shift 2
                ;;
            --chart)
                chart_name="$2"
                shift 2
                ;;
            --chartversion)
                chart_version="$2"
                shift 2
                ;;
            --scanner)
                scanner="$2"
                shift 2
                ;;
            *)
                echo "Unknown parameter: $arg"
                exit 1
                ;;
        esac
    done
}

# Main function
main() {
    # Parse arguments
    parse_arguments "$@"


    # Validate arguments
    if [[ -z "${repo_url:-}" || -z "${chart_name:-}" || -z "${chart_version:-}" || -z "${scanner:-}" ]]; then
        echo "Usage: $0 --repo-url=<url> --repo-name=<name> --chart=<chart_name> --chart-version=<version> --scanner=<scan_tool>"
        echo "Tools: grype, trivy"
        exit 1
    fi

    # Check if the scanner is valid
    if [[ "$scanner" != "grype" && "$scanner" != "trivy" ]]; then
        echo "Error: Unknown scanner $scanner. Use 'grype' or 'trivy'."
        exit 1
    fi

    # Check if necessary tools are installed
    check_dependencies

    # Add the provided Helm repo
    helm repo add "$repo_name" "$repo_url"
    helm repo update

    # Fetch the chart (we will use a temporary directory for this)
    temp_dir=$(mktemp -d)
    echo "Fetching chart $chart_name version $chart_version from $repo_url into temporary directory: $temp_dir"
    helm fetch "$repo_name"/"$chart_name" --version "$chart_version" --untar --untardir "$temp_dir"

    # CSV file to store results with the date as a prefix
    output_csv="$(date +%Y-%m-%d)_scan_results.csv"
    echo "image:tag,component/library,vulnerability,severity" > "$output_csv"

    # Temporary file for scan results
    scan_results=$(mktemp)

    # Extract images from the Helm chart
    images=$(extract_images "$temp_dir/$chart_name")

    # List of images
    echo $images
    # Scan each image using the selected tool
    for image in $images; do
        echo "Processing image: $image"

        # Run the appropriate scan tool
        if [[ "$scanner" == "grype" ]]; then
            scan_with_grype "$image" "$scan_results"
        elif [[ "$scanner" == "trivy" ]]; then
            scan_with_trivy "$image" "$scan_results"
        fi

        # Convert scan results to CSV
        convert_to_csv "$scanner" "$scan_results" "$image" "$output_csv"
    done

    # Cleanup temporary resources
    rm -rf "$temp_dir"
    rm -f "$scan_results"

    echo "All scans complete. Results saved to $output_csv."
}

main "$@"
