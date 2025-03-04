#!/usr/bin/env bash

set -e

# check if yq is installed
if ! command -v yq &> /dev/null
then
    echo "yq could not be found. Please install yq before running this script."
    exit 1
fi

# ask the user for the project name
read -p "Enter the project name: " project_name < /dev/tty

# ask for the project namespace. default is openad-models
read -p "Enter the project namespace (default: openad-models): " project_namespace < /dev/tty
project_namespace=${project_namespace:-openad-models}  # set the default value

# check if the project name is empty
if [ -z "$project_name" ]; then
  echo "Project name cannot be empty"
  exit 1
fi

# clone the openad-model-helm-template repository
git clone --depth 1 https://github.com/acceleratedscience/openad-model-helm-template.git

# add the project name to the helm chart
yq -i ".name = \"$project_name\"" openad-model-helm-template/helm-chart/Chart.yaml

# add the project name to the helmfile.yaml
yq -i ".releases[].name = \"$project_name\"" openad-model-helm-template/helmfile.yaml
yq -i ".releases[].namespace = \"$project_namespace\"" openad-model-helm-template/helmfile.yaml
yq -i ".releases[].chart = ./\"$project_name\"" openad-model-helm-template/helmfile.yaml

# Copy the helm chart templates to the charts directory
mkdir -p ./charts/$project_name
cp -r openad-model-helm-template/helm-chart ./charts/$project_name

# Copy the helmfile.yaml to the root directory
cp openad-model-helm-template/helmfile.yaml ./charts/helmfile.yaml

# cleanup
rm -rf openad-model-helm-template
