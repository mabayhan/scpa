# Helm Chart Image Vulnerability Scanner

## Description

This project is a Bash script (`scan_with_options.sh`) designed to automate the process of scanning container images defined in a Helm chart for vulnerabilities. It uses either **Anchore Grype** or **Aqua Trivy** for vulnerability scanning and outputs results in a CSV file with the following fields:

- `image:tag`
- `component/library`
- `vulnerability`
- `severity`

The script retrieves a specified Helm chart, extracts the container images it deploys, scans these images for vulnerabilities of severity **Medium** or higher, and saves the results in a CSV file named with the scan date.

---

## Features

1. **Support for Two Scanners**: Choose between Grype or Trivy for scanning container images.
2. **Customizable Helm Chart Retrieval**: Specify Helm repository URL, chart name, and chart version.
3. **CSV Output**: Outputs vulnerability scan results in a clear, structured format.
4. **Cleanup**: Automatically removes temporary resources after the process (unless any error occurs, in that case script keeps the temporary files for troubleshooting purposes).

---

## Requirements

- **Docker** (for running vulnerability scanners)
- **Helm** (for retrieving and templating Helm charts)
- **jq** (for processing JSON output from scanners)

---

## Usage

Run the script as follows:

```bash
./scan_with_options.sh --repourl <url> --chart <chart_name> --chartversion <version> --scanner <scan_tool>
```

### Parameters:

- `--repourl`: The URL of the Helm chart repository (e.g., `https://charts.bitnami.com/bitnami`).
- `--chart`: The name of the Helm chart (e.g., `wordpress`).
- `--chartversion`: The version of the Helm chart (e.g., `10.0.0`).
- `--scanner`: The scanning tool to use (`grype` or `trivy`).

### Example Command:

```bash
./scan_with_options.sh --repourl=https://charts.bitnami.com/bitnami --chart=wordpress --chartversion=10.0.0 --scanner=grype
```

---

## Assumptions & Design Decisions

1. The user has access to a Helm repository that contains the desired chart.
2. All container images used in the Helm chart can be scanned directly without requiring special authentication.
3. The script focuses on vulnerabilities of severity **Medium** or higher to prioritize actionable issues.
4. Cleanup of temporary files and directories is handled automatically to avoid clutter.

---

## AI Assistance

This project involved AI assistance in the following areas:

1. **Code Suggestions**: The Bash script structure, argument parsing, and the logic for handling scanners were partially AI-generated. Adjustments included:
   - Adding error handling for missing dependencies.
   - Fine-tuning `jq` queries for Grype and Trivy JSON output.
   - Ensuring compatibility with Helm templates.
2. **Debugging**: The AI suggested fixes for parsing Helm chart images and handling cases where multiple images were defined in a chart.

These suggestions were manually tested and refined to align with the project's requirements.

---

## AI Mistakes

AI failed to create jq queries properly and for this I believe it does not know latest output format. I had to adjust queries to match with outputs.

Also while scanning the image names, regex written by ai was not properly grabbing the image names, I had to adjust the query.

---

## Improvements

Given more time, the following improvements could be made:

1. **Enhanced Error Handling**: Add more descriptive error messages and edge-case handling, such as invalid chart versions, missing Docker images, failed output.
2. **Parallel Scanning**: Improve performance by scanning multiple images in parallel.
3. **Dynamic Severity Threshold**: Allow users to define their own severity threshold for filtering vulnerabilities.
4. **Integration Tests**: Add automated tests to validate the script’s functionality in various scenarios.
5. **Logging**: Include a logging mechanism to track script activity for troubleshooting.

---

---

## How I Created This Script?

1. I created bash script using my existing snippets. No comment, no failsafe check.
2. I provided exact prompt in the assignemt to ChatGPT with my code and reviewed the output. I believe even if I just provide the assignment, ChatGPT will output usable code.
3. I run the code against a couple public helm charts for sanity check. I've found a couple errors and tried to fix as much as possible within givin time.
4. After finishing the code, I created a step by step instructions with high level technical not detailed infromation. I provided the next prompt and my notes including instructions and imporovement suggestions to create README file.
5. As like the code, I reviewed the README file as well.

---

## License

This project is open source and available under the BSD License.

---
