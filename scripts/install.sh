#!/usr/bin/env bash

# Function to add colors
GREEN=$(tput setaf 2)
YELLOW=$(tput setaf 3)
BLUE=$(tput setaf 4)
BOLD=$(tput bold)
RESET=$(tput sgr0)

# Constants
INSTALL_PATH="./charts"

# Ensure script stops on error
set -e

# Validate dependencies
command -v git >/dev/null 2>&1 || { echo >&2 "git is required but not installed. Aborting."; exit 1; }
command -v yq >/dev/null 2>&1 || { echo >&2 "yq is required but not installed. Aborting."; exit 1; }

# Function to validate project name
validate_project_name() {
    local project_name="$1"
    
    # Optional: Add more validation if needed (e.g., must start with a letter)
    if [[ ! "$project_name" =~ ^[a-zA-Z][a-zA-Z0-9-]*$ ]]; then
        echo "❌ Error: Project name must start with a letter and can only contain letters, numbers, and hyphens."
        return 1
    fi
    
    return 0
}

# Function to get user input
get_input() {
    local prompt="$1"
    local default="$2"
    local input

    while true; do
        if [ -n "$default" ]; then
            read -p "🔹 $prompt [$default]: " input < /dev/tty
            input=${input:-$default}
        else
            read -p "🔹 $prompt: " input < /dev/tty
        fi

        if [ -n "$input" ]; then
            echo "$input"
            break
        else
            echo "Input cannot be empty. Please try again."
        fi
    done
}

# Function to check if project already exists
check_project_exists() {
    local project_name="$1"
    
    # Assume no project exists if charts directory is empty or doesn't exist
    if [ ! -d "$INSTALL_PATH" ] || [ -z "$(ls -A $INSTALL_PATH 2>/dev/null)" ]; then
        return 1
    fi
    
    # Check if the project directory exists
    if [ -d "$INSTALL_PATH/$project_name" ]; then
        echo "❌ Error: A project with the name '$project_name' already exists."
        return 0
    fi

    # Check if the project name is already in helmfile.yaml
    if [ -f "$INSTALL_PATH/helmfile.yaml" ]; then
        local existing_project=$(yq ".releases[].name" $INSTALL_PATH/helmfile.yaml 2>/dev/null | grep "^$project_name$")
        if [ -n "$existing_project" ]; then
            echo "❌ Error: A project with the name '$project_name' is already configured in helmfile.yaml."
            return 0
        fi
    fi

    return 1
}

# Ensure releases section exists in helmfile.yaml
ensure_releases_section() {
    local helmfile_path="$1"

    # Check if releases section exists
    if ! yq '.releases' "$helmfile_path" > /dev/null 2>&1; then
        # Add releases section if it doesn't exist
        yq '. += {"releases": []}' "$helmfile_path"
    fi
}

# Get project details with validation
while true; do
    project_name=$(get_input "Enter the project name")

    # Validate project name
    if ! validate_project_name "$project_name"; then
        continue
    fi

    # Check if project exists
    if check_project_exists "$project_name"; then
        continue
    fi

    break
done

# Get project namespace with validation
while true; do
    project_namespace=$(get_input "Enter the project namespace" "openad-models")

    # Validate project name
    if ! validate_project_name "$project_namespace"; then
        continue
    fi

    break
done

# Clone repository
git clone --depth 1 https://github.com/acceleratedscience/openad-model-helm-template.git > /dev/null 2>&1

# check if charts directory exists
if [ ! -f "$INSTALL_PATH/helmfile.yaml" ]; then
    mkdir -p $INSTALL_PATH
    # copy helmfile.yaml to charts directory
    cp openad-model-helm-template/helmfile.yaml $INSTALL_PATH/helmfile.yaml
    # Ensure releases section exists in helmfile.yaml
    ensure_releases_section $INSTALL_PATH/helmfile.yaml
fi

# Prepare directories
mkdir -p $INSTALL_PATH/$project_name
cp -r openad-model-helm-template/helm/* $INSTALL_PATH/$project_name
# Add project name to helm chart
yq -i ".name = \"$project_name\"" $INSTALL_PATH/$project_name/Chart.yaml
# Update helmfile.yaml
yq -i ".releases += [{\"name\": \"$project_name\", \"namespace\": \"$project_namespace\", \"chart\": \"./$project_name\"}]" $INSTALL_PATH/helmfile.yaml

# Cleanup
rm -rf openad-model-helm-template

echo -e "\n   ${GREEN}🎉 Project setup complete for ${BOLD}$project_name${RESET}\n"
echo "   Next steps:"
echo -e "   ${YELLOW}📝 Update the values file: 🛠️ '$INSTALL_PATH/$project_name/values.yaml'${RESET}"
echo -e "   ${BLUE}🚀 Deploy the Helm chart:  ⚓ ${BOLD}'helmfile -f $INSTALL_PATH/helmfile.yaml apply'${RESET}\n"
