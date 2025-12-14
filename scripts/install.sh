#!/usr/bin/env bash

# Ensure script stops on error
set -euo pipefail

# Function to add colors
GREEN=$(tput setaf 2)
YELLOW=$(tput setaf 3)
BLUE=$(tput setaf 4)
RED=$(tput setaf 1)
BOLD=$(tput bold)
RESET=$(tput sgr0)

# Constants
INSTALL_PATH="./charts"
SUCCESS=false

# Header and Footer
print_header() {
    echo -e "${BLUE}${BOLD}-----------------------------------------------------${RESET}"
    echo -e "${BLUE}${BOLD}  🚀 AISUITE Helm Template Installer 🚀         ${RESET}"
    echo -e "${BLUE}${BOLD}-----------------------------------------------------${RESET}\n"
}

print_footer() {
    echo -e "\n${BLUE}${BOLD}-----------------------------------------------------${RESET}"
    echo -e "${BLUE}${BOLD}  Installation process finished.                     ${RESET}"
    echo -e "${BLUE}${BOLD}-----------------------------------------------------${RESET}"
}

# Trap to print footer on exit
trap "print_footer" EXIT

# Validate dependencies
command -v git >/dev/null 2>&1 || { echo >&2 "${RED}❌ Error: git is required but not installed. Aborting.${RESET}"; exit 1; }
command -v yq >/dev/null 2>&1 || { echo >&2 "${RED}❌ Error: yq is required but not installed. Aborting.${RESET}"; exit 1; }

# Function to validate project name
validate_project_name() {
    local project_name="$1"
    
    # Optional: Add more validation if needed (e.g., must start with a letter)
    if [[ ! "$project_name" =~ ^[a-zA-Z][a-zA-Z0-9-]*$ ]]; then
        echo "${RED}❌ Error: Project name must start with a letter and can only contain letters, numbers, and hyphens.${RESET}" >&2
        return 1
    fi
    
    return 0
}

# Function to validate port number
validate_port() {
    local port="$1"
    if [[ ! "$port" =~ ^[0-9]+$ ]] || [ "$port" -lt 1 ] || [ "$port" -gt 65535 ]; then
        echo "${RED}❌ Error: Port must be a number between 1 and 65535.${RESET}" >&2
        return 1
    fi
    return 0
}

# Function to get user input
get_input() {
    local prompt="$1"
    local default="${2:-}"
    local allow_empty="${3:-false}"
    local input

    while true; do
        if [ -n "$default" ]; then
            read -p "${BLUE}❓ $prompt${RESET} ${BOLD}[$default]${RESET}: " input < /dev/tty
            input=${input:-$default}
        else
            read -p "${BLUE}❓ $prompt${RESET}: " input < /dev/tty
        fi

        if [ -n "$input" ]; then
            echo "$input"
            break
        elif [ "$allow_empty" = true ]; then
            echo ""
            break
        else
            echo "${RED}❌ Input cannot be empty. Please try again.${RESET}" >&2
        fi
    done
}

# Function to confirm overwrite
confirm_overwrite() {
    if [ -d "$INSTALL_PATH" ] && [ -n "$(ls -A "$INSTALL_PATH" 2>/dev/null)" ]; then
        echo "${YELLOW}⚠️ Warning: The directory '$INSTALL_PATH' already exists and is not empty.${RESET}"
        read -p "${YELLOW}Continuing may overwrite shared configuration files. Do you want to proceed? [y/N]: ${RESET}" -n 1 -r REPLY < /dev/tty
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            echo "${BLUE}Operation cancelled.${RESET}"
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
        echo "${RED}❌ Error: A project with the name '$project_name' already exists.${RESET}" >&2
        return 0
    fi

    # Check if the project name is already in helmfile.yaml
    if [ -f "$INSTALL_PATH/helmfile.yaml" ]; then
        local existing_project=$(yq ".releases[].name" $INSTALL_PATH/helmfile.yaml 2>/dev/null | grep "^$project_name$")
        if [ -n "$existing_project" ]; then
            echo "${RED}❌ Error: A project with the name '$project_name' is already configured in helmfile.yaml.${RESET}" >&2
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

# Function for a simple spinner
show_progress() {
    local pid=$1
    local delay=0.1
    local spinstr="-\|/"
    local i=0
    while kill -0 $pid 2>/dev/null; do
        i=$(( (i+1) % ${#spinstr} ))
        printf "\r  ${BLUE}%c ${RESET}" "${spinstr:$i:1}"
        sleep $delay
    done
    printf "\r   \r" # Clear the spinner line
}

# Create a temporary directory for the setup
TEMP_DIR=$(mktemp -d)

# Function to handle script cleanup
cleanup_on_exit() {
    # Always remove the temp directory
    rm -rf "$TEMP_DIR"

    if [ "$SUCCESS" = "true" ]; then
        echo -e "\n${GREEN}${BOLD}🎉 Installation Complete! 🎉${RESET}"
        echo -e "${GREEN}Project '${project_name}' has been successfully set up.${RESET}\n"
        echo -e "${BOLD}Next Steps:${RESET}"
        echo -e "  ${YELLOW}📝 Update Chart Values: ${RESET}${BOLD}$INSTALL_PATH/$project_name/values.yaml${RESET}"
        echo -e "  ${BLUE}🚀 Deploy The Helm Chart: ${RESET}${BOLD}helmfile -f $INSTALL_PATH/helmfile.yaml apply${RESET}"
        echo -e "  ${BLUE}🤖 Deploy With ArgoCD: ${RESET}${BOLD}kubectl apply -f $INSTALL_PATH/argocd/application.yaml${RESET}\n"
    else
        echo -e "\n${RED}Installation encountered an error or was interrupted.${RESET}"
        echo -e "${YELLOW}Temporary files have been cleaned up.${RESET}"
    fi
}
trap cleanup_on_exit EXIT

# Print header
print_header

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
repo_url=$(get_input "Enter the git repository URL" "$(git config --get remote.origin.url 2>/dev/null || echo '')")

# Get application port with validation
while true; do
    application_port=$(get_input "Enter the application port" "8080")
    if validate_port "$application_port"; then
        break
    fi
done

# Get liveness port with validation
while true; do
    liveness_port=$(get_input "Enter the liveness probe port (optional, empty to disable)" "" true)
    if [ -z "$liveness_port" ] || validate_port "$liveness_port"; then
        break
    fi
done

# --- All operations will happen in the temp dir ---
CLONE_DIR="$TEMP_DIR/openad-model-helm-template"
TARGET_PROJECT_DIR="$TEMP_DIR/$project_name"
TARGET_ARGOCD_DIR="$TEMP_DIR/argocd"
TARGET_HELMFILE="$TEMP_DIR/helmfile.yaml"

echo -e "${BLUE}⚙️  Cloning repository...${RESET}"
git clone --depth 1 https://github.com/acceleratedscience/openad-model-helm-template.git "$CLONE_DIR" > /dev/null 2>&1 &
show_progress $!
echo -e "${GREEN}✅ Repository cloned.${RESET}"


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
yq -i ".buildConfig.gitUri = \"$repo_url\"" "$TARGET_PROJECT_DIR/values.yaml"
yq -i ".service.targetPort = $application_port" "$TARGET_PROJECT_DIR/values.yaml"
yq -i ".readinessProbe.httpGet.port = $application_port" "$TARGET_PROJECT_DIR/values.yaml"

if [ -n "$liveness_port" ]; then
    yq -i ".livenessProbe.httpGet.port = $liveness_port" "$TARGET_PROJECT_DIR/values.yaml"
else
    yq -i ".livenessProbe = null" "$TARGET_PROJECT_DIR/values.yaml"
fi

yq -i ".releases += [{\"name\": \"$project_name\", \"namespace\": \"$project_namespace\", \"chart\": \"./$project_name\"}]" "$TARGET_HELMFILE"
yq -i "
    .metadata.name = \"$project_name\" |
    .spec.destination.namespace = \"$project_namespace\" |
    .spec.source.repoURL = \"$repo_url\" |
    .spec.source.path = \"charts/$project_name\" |
    .spec.source.helm.releaseName = \"$project_name\" |
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
