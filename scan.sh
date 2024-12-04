#!/bin/bash

set -euo pipefail

check_dependencies() {
    for cmd in docker helm jq; do
        if ! command -v $cmd &>/dev/null; then
            exit 1
        fi
    done
}

extract_images() {
    local chart_dir=$1
    helm template "$chart_dir" | grep -E 'image: ' | awk '{print $2}' | tr -d '"' | sort | uniq
}

scan_with_grype() {
    local image=$1
    local output=$2
    docker run --rm -v /var/run/docker.sock:/var/run/docker.sock anchore/grype $image -o json >"$output"
}

convert_to_csv() {
    local grype_json=$1
    local image=$2
    local csv_file=$3

    jq -r --arg image "$image" '
        .matches[] |
        select(.vulnerability.severity == "High" or .vulnerability.severity == "Critical" or .vulnerability.severity == "Medium") |
        [$image, .artifact.name, .vulnerability.id, .vulnerability.severity] |
        @csv
    ' "$grype_json" >>"$csv_file"
}

main() {
    check_dependencies

    chart_dir=$1

    if [[ ! -d $chart_dir ]]; then
        exit 1
    fi

    output_csv="scan_results.csv"
    echo "image:tag,component/library,vulnerability,severity" >"$output_csv"

    grype_results=$(mktemp)

    images=$(extract_images "$chart_dir")

    for image in $images; do
        scan_with_grype "$image" "$grype_results"
        convert_to_csv "$grype_results" "$image" "$output_csv"
    done

    rm -f "$grype_results"
}

main "$@"
