#!/bin/bash

set -e

FILE="Jenkinsfile"

if [ ! -f "$FILE" ]; then
  echo "Error: $FILE not found in current directory."
  exit 1
fi

if [ ! -d ".git" ]; then
  echo "Error: this is not a Git repository."
  exit 1
fi

VARS=(
  "AWS_REGION"
  "AWS_ACCOUNT_ID"
  "ECR_REPOSITORY"
  "PROD_APP_DIR"
  "SSH_TARGET"
  "APP_PORT"
  "MONGO_URI"
)

ask_yes_no() {
  local prompt="$1"
  local default="${2:-Y}"
  local answer

  while true; do
    if [ "$default" = "Y" ]; then
      read -p "$prompt (Y/n): " answer
      answer="${answer:-Y}"
    else
      read -p "$prompt (y/N): " answer
      answer="${answer:-N}"
    fi

    case "$answer" in
    Y | y) return 0 ;;
    N | n) return 1 ;;
    *) echo "Please answer y or n." ;;
    esac
  done
}

get_current_value() {
  local var_name="$1"
  grep -E "^[[:space:]]*$var_name[[:space:]]*=" "$FILE" |
    sed -E "s/^[[:space:]]*$var_name[[:space:]]*=[[:space:]]*'(.*)'/\1/" |
    head -n 1
}

escape_replacement() {
  printf '%s' "$1" | sed 's/[&|]/\\&/g'
}

update_value() {
  local var_name="$1"
  local raw_value="$2"
  local new_value
  new_value=$(escape_replacement "$raw_value")

  sed -i.bak "s|^\([[:space:]]*$var_name[[:space:]]*=[[:space:]]*'\\).*\('\\)|\\1$new_value\\2|" "$FILE"
  rm -f "${FILE}.bak"
}

echo "Updating Jenkinsfile environment values..."
echo

for var in "${VARS[@]}"; do
  current_value=$(get_current_value "$var")

  echo "Current value for $var:"
  echo "  $current_value"

  if ask_yes_no "Keep this value?" "Y"; then
    echo "$var kept as-is."
  else
    read -p "Enter new value for $var: " new_value
    update_value "$var" "$new_value"
    echo "$var updated."
  fi

  echo
done

echo "Derived values reminder:"
echo "- IMAGE_TAG stays based on Jenkins BUILD_NUMBER."
echo "- IMAGE_URI is built automatically from AWS_ACCOUNT_ID, AWS_REGION, and ECR_REPOSITORY."
echo

echo "Showing diff for Jenkinsfile..."
git diff -- "$FILE"
echo

if ask_yes_no "Do you want to stage all changes with 'git add .'?" "Y"; then
  git add .
  echo "Changes staged."
else
  echo "Skipping git add ."
fi

echo
if ask_yes_no "Do you want to commit now?" "Y"; then
  read -p "Enter commit message: " commit_message

  if [ -z "$commit_message" ]; then
    echo "Commit message cannot be empty. Skipping commit."
  else
    git commit -m "$commit_message"
    echo "Commit created."
  fi
else
  echo "Skipping commit."
fi

echo
if ask_yes_no "Do you want to push to origin main?" "N"; then
  git push origin main
  echo "Pushed to origin main."
else
  echo "Push skipped."
fi
