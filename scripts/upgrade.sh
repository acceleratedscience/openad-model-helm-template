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
    echo -e "${BLUE}${BOLD}  ⬆️  AISUITE Helm Template Upgrade ⬆️          ${RESET}"
    echo -e "${BLUE}${BOLD}-----------------------------------------------------${RESET}\n"
}

print_footer() {
    if [ "$SUCCESS" = "true" ]; then
        echo -e "\n${BLUE}${BOLD}-----------------------------------------------------${RESET}"
        echo -e "${BLUE}${BOLD}  Upgrade process finished successfully.             ${RESET}"
        echo -e "${BLUE}${BOLD}-----------------------------------------------------${RESET}"
    else
        echo -e "\n${RED}${BOLD}-----------------------------------------------------${RESET}"
        echo -e "${RED}${BOLD}  Upgrade process failed or was interrupted.         ${RESET}"
        echo -e "${RED}${BOLD}-----------------------------------------------------${RESET}"
    fi
}

# Create a temporary directory
TEMP_DIR=$(mktemp -d)

# Cleanup function
cleanup() {
    rm -rf "$TEMP_DIR"
    print_footer
}

# Trap to cleanup and print footer on exit
trap "cleanup" EXIT

# Validate dependencies
command -v git >/dev/null 2>&1 || { echo >&2 "${RED}❌ Error: git is required but not installed. Aborting.${RESET}"; exit 1; }
command -v yq >/dev/null 2>&1 || { echo >&2 "${RED}❌ Error: yq is required but not installed. Aborting.${RESET}"; exit 1; }
command -v diff >/dev/null 2>&1 || { echo >&2 "${RED}❌ Error: diff is required but not installed. Aborting.${RESET}"; exit 1; }

# Function to get user input
get_input() {
    local prompt="$1"
    local default="${2:-}"
    local input

    if [ -n "$default" ]; then
        read -p "${BLUE}❓ $prompt${RESET} ${BOLD}[$default]${RESET}: " input < /dev/tty
        input=${input:-$default}
    else
        read -p "${BLUE}❓ $prompt${RESET}: " input < /dev/tty
    fi

    echo "$input"
}

print_header

# Function to list available projects
list_projects() {
    local projects=()
    if [ -d "$INSTALL_PATH" ]; then
        for dir in "$INSTALL_PATH"/*/; do
            if [ -f "${dir}Chart.yaml" ]; then
                projects+=("$(basename "$dir")")
            fi
        done
    fi
    echo "${projects[@]}"
}

# Get project name
projects=($(list_projects))

if [ ${#projects[@]} -eq 0 ]; then
    echo "${RED}❌ Error: No existing projects found in $INSTALL_PATH.${RESET}"
    exit 1
fi

echo -e "${BLUE}Available projects:${RESET}"
for i in "${!projects[@]}"; do
    echo "  $((i+1)). ${projects[$i]}"
done

while true; do
    project_input=$(get_input "Enter the project name or number to upgrade")
    
    # Check if input is a number
    if [[ "$project_input" =~ ^[0-9]+$ ]] && [ "$project_input" -ge 1 ] && [ "$project_input" -le "${#projects[@]}" ]; then
        project_name="${projects[$((project_input-1))]}"
        break
    # Check if input is a valid project name
    elif [[ " ${projects[*]} " =~ " $project_input " ]]; then
        project_name="$project_input"
        break
    else
        echo "${RED}❌ Invalid selection. Please try again.${RESET}"
    fi
done

echo -e "${GREEN}✅ Selected project: $project_name${RESET}"

PROJECT_DIR="$INSTALL_PATH/$project_name"

# --- Version check ---
echo -e "${BLUE}🔎 Checking for new versions...${RESET}"
LATEST_VERSION=$(git ls-remote --tags --sort="v:refname" https://github.com/acceleratedscience/openad-model-helm-template.git | tail -n1 | sed 's/.*\///; s/\^{}//')
CURRENT_VERSION=$(yq '.version' "$PROJECT_DIR/Chart.yaml")

echo -e "${GREEN}✅ Current version: $CURRENT_VERSION${RESET}"
echo -e "${GREEN}✅ Latest version:  $LATEST_VERSION${RESET}"

if [ "$CURRENT_VERSION" == "$LATEST_VERSION" ]; then
    echo -e "${YELLOW}⚠️ Project is already up to date.${RESET}"
    exit 0
fi

read -p "${BLUE}❓ Do you want to upgrade to version $LATEST_VERSION? [y/N]: ${RESET}" -n 1 -r REPLY < /dev/tty
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "${BLUE}Operation cancelled.${RESET}"
    exit 1
fi

# Function to backup project
backup_project() {
    local timestamp=$(date +%Y%m%d%H%M%S)
    BACKUP_DIR="${PROJECT_DIR}_backup_${timestamp}"
    echo -e "${BLUE}📦 Creating backup at $BACKUP_DIR...${RESET}"
    cp -r "$PROJECT_DIR" "$BACKUP_DIR"
    echo -e "${GREEN}✅ Backup created.${RESET}"
}

backup_project

# --- Clone and checkout the tagged release ---
CLONE_DIR="$TEMP_DIR/openad-model-helm-template"
echo -e "${BLUE}⚙️  Cloning template version $LATEST_VERSION...${RESET}"
git clone --depth 1 --branch "$LATEST_VERSION" https://github.com/acceleratedscience/openad-model-helm-template.git "$CLONE_DIR" > /dev/null 2>&1
echo -e "${GREEN}✅ Repository cloned.${RESET}"

NEW_TEMPLATE_DIR="$CLONE_DIR/helm"

# Merge values.yaml
echo -e "${BLUE}🔄 Merging values.yaml...${RESET}"

# Strip comments from the project's values.yaml to prevent duplication
yq eval '... comments=""' "$PROJECT_DIR/values.yaml" > "$TEMP_DIR/values_nocomments.yaml"

# Merge the new template's values with the comment-stripped user values
yq eval-all 'select(fileIndex == 0) * select(fileIndex == 1)' "$NEW_TEMPLATE_DIR/values.yaml" "$TEMP_DIR/values_nocomments.yaml" > "$TEMP_DIR/merged_values.yaml"

if [ -s "$TEMP_DIR/merged_values.yaml" ]; then
    cp "$TEMP_DIR/merged_values.yaml" "$PROJECT_DIR/values.yaml"
    echo -e "${GREEN}✅ values.yaml merged.${RESET}"
else
    echo "${RED}❌ Error merging values.yaml.${RESET}"
    exit 1
fi

# Update Chart.yaml
echo -e "${BLUE}🔄 Updating Chart.yaml...${RESET}"
EXISTING_NAME=$(yq '.name' "$PROJECT_DIR/Chart.yaml")
cp "$NEW_TEMPLATE_DIR/Chart.yaml" "$PROJECT_DIR/Chart.yaml"
yq -i ".name = \"$EXISTING_NAME\"" "$PROJECT_DIR/Chart.yaml"
echo -e "${GREEN}✅ Chart.yaml updated.${RESET}"

# Update templates/
echo -e "${BLUE}🔄 Updating templates/...${RESET}"
rm -rf "$PROJECT_DIR/templates"
cp -r "$NEW_TEMPLATE_DIR/templates" "$PROJECT_DIR/"
echo -e "${GREEN}✅ templates/ directory updated.${RESET}"

echo -e "${BLUE}📝 Summary of changes:${RESET}"

if [ -d "$BACKUP_DIR" ]; then
    echo -e "${BOLD}Changes in values.yaml:${RESET}"
    # Use diff but don't exit on error (diff returns 1 if differences found)
    diff -u "$BACKUP_DIR/values.yaml" "$PROJECT_DIR/values.yaml" || true
else
    echo "${YELLOW}⚠️ Could not find backup to compare changes.${RESET}"
fi

SUCCESS=true
