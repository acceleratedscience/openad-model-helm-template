#!/usr/bin/env bash

# Ensure script stops on error
set -euo pipefail

# Function to add colors
GREEN=$(tput setaf 2)
YELLOW=$(tput setaf 3)
BLUE=$(tput setaf 4)
BOLD=$(tput bold)
RESET=$(tput sgr0)

# Constants
INSTALL_PATH="./charts"
SUCCESS=false

# Validate dependencies
command -v git >/dev/null 2>&1 || { echo >&2 "git is required but not installed. Aborting."; exit 1; }
command -v yq >/dev/null 2>&1 || { echo >&2 "yq is required but not installed. Aborting."; exit 1; }

# Function to validate project name
validate_project_name() {
    local project_name="$1"
    
    # Optional: Add more validation if needed (e.g., must start with a letter)
    if [[ ! "$project_name" =~ ^[a-zA-Z][a-zA-Z0-9-]*$ ]]; then
        echo "❌ Error: Project name must start with a letter and can only contain letters, numbers, and hyphens." >&2
        return 1
    fi
    
    return 0
}

# Function to get user input
get_input() {
    local prompt="$1"
    local default="${2:-}"
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
            echo "Input cannot be empty. Please try again." >&2
        fi
    done
}

# Function to confirm overwrite
confirm_overwrite() {
    if [ -d "$INSTALL_PATH" ] && [ -n "$(ls -A "$INSTALL_PATH" 2>/dev/null)" ]; then
        echo "${YELLOW}Warning: The directory '$INSTALL_PATH' already exists and is not empty.${RESET}"
        read -p "Continuing may overwrite shared configuration files. Do you want to proceed? [y/N]: " -n 1 -r REPLY < /dev/tty
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            echo "Operation cancelled."
            exit 1
        fi
    fi
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
        echo "❌ Error: A project with the name '$project_name' already exists." >&2
        return 0
    fi

    # Check if the project name is already in helmfile.yaml
    if [ -f "$INSTALL_PATH/helmfile.yaml" ]; then
        local existing_project=$(yq ".releases[].name" $INSTALL_PATH/helmfile.yaml 2>/dev/null | grep "^$project_name$")
        if [ -n "$existing_project" ]; then
            echo "❌ Error: A project with the name '$project_name' is already configured in helmfile.yaml." >&2
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
        yq -i '. += {"releases": []}' "$helmfile_path"
    fi
}

# Create a temporary directory for the setup
TEMP_DIR=$(mktemp -d)

# Function to handle script cleanup
cleanup_on_exit() {
    # Always remove the temp directory
    rm -rf "$TEMP_DIR"

    if [ "$SUCCESS" = "true" ]; then
        echo -e "\n   ${GREEN}🎉 Project setup complete for ${BOLD}$project_name${RESET}\n"
        echo "   Next steps:"
        echo -e "   ${YELLOW}📝 Update Chart Values${RESET}   --> $INSTALL_PATH/$project_name/values.yaml"
        echo -e "   ${BLUE}🚀 Deploy The Helm Chart${RESET} --> helmfile -f $INSTALL_PATH/helmfile.yaml apply"
        echo -e "   ${BLUE}🤖 Deploy With ArgoCD${RESET}    --> kubectl apply -f $INSTALL_PATH/argocd/application.yaml\n"
    else
        echo "An error occurred or script was interrupted"
        echo "Cleanup finished."
    fi
}
trap cleanup_on_exit EXIT

# Prompt for overwrite if necessary
confirm_overwrite

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

# Get git repo URL
repo_url=$(get_input "Enter the Git repository URL" "$(git config --get remote.origin.url 2>/dev/null || echo '')")

# --- All operations will happen in the temp dir ---
CLONE_DIR="$TEMP_DIR/openad-model-helm-template"
TARGET_PROJECT_DIR="$TEMP_DIR/$project_name"
TARGET_ARGOCD_DIR="$TEMP_DIR/argocd"
TARGET_HELMFILE="$TEMP_DIR/helmfile.yaml"

# Clone repository into temp dir
git clone --depth 1 https://github.com/acceleratedscience/openad-model-helm-template.git "$CLONE_DIR" > /dev/null 2>&1

# Prepare directories in temp
mkdir -p "$TARGET_PROJECT_DIR"
cp -r "$CLONE_DIR/helm/"* "$TARGET_PROJECT_DIR"
cp -r "$CLONE_DIR/argocd" "$TARGET_ARGOCD_DIR"

# Handle helmfile.yaml in temp
if [ -f "$INSTALL_PATH/helmfile.yaml" ]; then
    cp "$INSTALL_PATH/helmfile.yaml" "$TARGET_HELMFILE"
else
    cp "$CLONE_DIR/helmfile.yaml" "$TARGET_HELMFILE"
    ensure_releases_section "$TARGET_HELMFILE"
fi

# Modify files in temp
yq -i ".name = \"$project_name\"" "$TARGET_PROJECT_DIR/Chart.yaml"
yq -i ".releases += [{\"name\": \"$project_name\", \"namespace\": \"$project_namespace\", \"chart\": \"./$project_name\"}]" "$TARGET_HELMFILE"
yq -i "
    .metadata.name = \"$project_name\" |
    .spec.destination.namespace = \"$project_namespace\" |
    .spec.source.repoURL = \"$repo_url\" |
    .spec.source.path = \"charts/$project_name\" |
    .spec.ignoreDifferences[0].name = \"$project_name\" |
    .spec.ignoreDifferences[0].jqPathExpressions[0] = \".spec.template.spec.containers[] | select(.name == \\\"$project_name\\\") | .image\"
" "$TARGET_ARGOCD_DIR/application.yaml"

# --- Commit phase: Move files to final destination ---
mkdir -p "$INSTALL_PATH"
# Use cp to handle overwriting existing directories gracefully
cp -R "$TARGET_PROJECT_DIR" "$INSTALL_PATH/"
# Handle argocd application file by appending
mkdir -p "$INSTALL_PATH/argocd"
if [ -f "$INSTALL_PATH/argocd/application.yaml" ] && [ -s "$INSTALL_PATH/argocd/application.yaml" ]; then
    # Append to existing non-empty file
    echo "---" >> "$INSTALL_PATH/argocd/application.yaml"
    cat "$TARGET_ARGOCD_DIR/application.yaml" >> "$INSTALL_PATH/argocd/application.yaml"
else
    # Move the new file if destination is empty or doesn't exist
    mv "$TARGET_ARGOCD_DIR/application.yaml" "$INSTALL_PATH/argocd/"
fi
cp -R "$TARGET_HELMFILE" "$INSTALL_PATH/"

SUCCESS=true
