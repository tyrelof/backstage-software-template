#!/bin/bash

set -e

# ---------------------------------------------
# Colors
# ---------------------------------------------
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
RESET='\033[0m'

trap "echo -e '\n${RED}✋ Process interrupted. Exiting.${RESET}'; exit 1" SIGINT

# ---------------------------------------------
# Git Info
# ---------------------------------------------
current_branch=$(git rev-parse --abbrev-ref HEAD)
remote_origin=$(git remote get-url origin)

echo -e "${BLUE}🚀 Current branch: ${YELLOW}${current_branch}${RESET}"
echo -e "${CYAN}🔗 Remote origin: ${remote_origin}${RESET}"

# Detect and show Git auth method
if [[ "$remote_origin" == git@* ]]; then
    echo -e "${CYAN}🔐 Auth Method: SSH (key-based)${RESET}"
elif [[ "$remote_origin" == https://* ]]; then
    echo -e "${CYAN}🔐 Auth Method: HTTPS (token or password)${RESET}"
else
    echo -e "${YELLOW}⚠️  Unknown Git auth method in use.${RESET}"
fi

echo -e "\n${CYAN}🔍 Git status:${RESET}"
git status

# ---------------------------------------------
# Check for uncommitted changes or unpushed commits
# ---------------------------------------------
has_changes=$(git status --porcelain)
has_unpushed=$(git log origin/"$current_branch"..HEAD || true)

if [[ -z "$has_changes" && -z "$has_unpushed" ]]; then
    echo -e "\n${GREEN}✅ Nothing to commit or push.${RESET}"
    exit 0
fi

if [[ -z "$has_changes" && -n "$has_unpushed" ]]; then
    echo -e "\n${YELLOW}⚠️  No file changes, but there are unpushed commits.${RESET}"
    read -r -p "📤 Retry pushing them now? [Y/n]: " confirm
    confirm=${confirm,,}  # to lowercase
    if [[ "$confirm" == "n" ]]; then
        echo -e "${BLUE}🛑 Push cancelled by user.${RESET}"
        exit 0
    fi

    echo -e "\n📤 Retrying push..."
    git push origin "$current_branch"
    echo -e "\n${GREEN}✅ Successfully pushed to '${current_branch}'!${RESET}"
    exit 0
fi

# ---------------------------------------------
# Commit message guide (Conventional Commits)
# ---------------------------------------------
echo ""
echo -e "${CYAN}💡 Recommended Commit Format:${RESET}"
echo -e "   ${YELLOW}<type>(<scope>): <message>${RESET}"
echo -e "   Example 1: ${GREEN}feat(auth): add JWT-based login${RESET}"
echo -e "   Example 2: ${GREEN}fix(ui): resolve navbar collapse issue${RESET}"
echo ""
echo -e "${BLUE}📘 Common types:${RESET}"
echo -e "   feat     → New feature"
echo -e "   fix      → Bug fix"
echo -e "   chore    → Maintenance, configs"
echo -e "   docs     → Documentation changes"
echo -e "   style    → Code style only (formatting, etc.)"
echo -e "   refactor → Code changes without feature/bug"
echo -e "   perf     → Performance improvements"
echo -e "   test     → Adding or fixing tests"
echo -e "   ci       → CI/CD-related changes"
echo -e "   build    → Build system/config changes"
echo -e "   revert   → Revert a previous commit"
echo ""
read -r -p "✏️  Enter commit message [default: auto-commit]: " commit_msg
commit_msg="${commit_msg:-auto-commit}"

# ---------------------------------------------
# Final confirmation
# ---------------------------------------------
if [[ "$current_branch" == "release" ]]; then
    echo -e "${RED}🚫 Forbidden: Do NOT push to 'release' from local!${RESET}"
    echo -e "${YELLOW}✅ All deployments must go through CI/CD only.${RESET}"
    exit 1
fi

# ---------------------------------------------
# Git push
# ---------------------------------------------
echo -e "\n📦 Adding, committing, and pushing..."
git add .
git commit -m "$commit_msg"
git push origin "$current_branch"

echo -e "\n${GREEN}✅ Successfully pushed to '${current_branch}'!${RESET}"
