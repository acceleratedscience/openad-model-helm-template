#!/usr/bin/env bash

set -e

# Validate dependencies
command -v git >/dev/null 2>&1 || { echo >&2 "git is required but not installed. Aborting."; exit 1; }
command -v yq >/dev/null 2>&1 || { echo >&2 "yq is required but not installed. Aborting."; exit 1; }

# Function to get user input
get_input() {
    local prompt="$1"
    local default="$2"
    local input

    while true; do
        if [ -n "$default" ]; then
            read -p "$prompt [$default]: " input < /dev/tty
            input=${input:-$default}
        else
            read -p "$prompt: " input < /dev/tty
        fi

        if [ -n "$input" ]; then
            echo "$input"
            break
        else
            echo "Input cannot be empty. Please try again."
        fi
    done
}

# Get project details
project_name=$(get_input "Enter the project name")
project_namespace=$(get_input "Enter the project namespace" "openad-models")

# Clone repository
git clone --depth 1 https://github.com/acceleratedscience/openad-model-helm-template.git

# Add project name to helm chart
yq -i ".name = \"$project_name\"" openad-model-helm-template/helm-chart/Chart.yaml

# Update helmfile.yaml
yq -i ".releases[].name = \"$project_name\"" openad-model-helm-template/helmfile.yaml
yq -i ".releases[].namespace = \"$project_namespace\"" openad-model-helm-template/helmfile.yaml
yq -i ".releases[].chart = \"./$project_name\"" openad-model-helm-template/helmfile.yaml

# Prepare directories
mkdir -p ./charts/$project_name
cp -r openad-model-helm-template/helm-chart/* ./charts/$project_name
cp openad-model-helm-template/helmfile.yaml ./charts/helmfile.yaml

# Cleanup
rm -rf openad-model-helm-template

echo "Project setup complete for $project_name in namespace $project_namespace"