#!/bin/bash

# ==============================================================================
# GITHUB MIGRATION TOOL
# Usage: ./script.sh [-y] [-n] [-r specific-repo]
# ==============================================================================

command -v gh >/dev/null 2>&1 || { echo "❌ Error: 'gh' not installed."; exit 1; }
command -v jq >/dev/null 2>&1 || { echo "❌ Error: 'jq' not installed."; exit 1; }
command -v git >/dev/null 2>&1 || { echo "❌ Error: 'git' not installed."; exit 1; }

AUTO_YES=false
RENAME_MODE=false
SPECIFIC_REPO=""

while getopts "ynr:" opt; do
  case $opt in
    y) AUTO_YES=true ;;
    n) RENAME_MODE=true ;;
    r) SPECIFIC_REPO="$OPTARG" ;;
    \?) echo "Invalid option: -$OPTARG" >&2; exit 1 ;;
  esac
done

echo "=========================================="
echo "   GITHUB MIGRATION TOOL"
echo "=========================================="

echo -n "Organisation SOURCE: "
read SOURCE_ORG

echo -n "User/Organisation DESTINATION: "
read DEST_OWNER

process_migration() {
    local SRC_NAME=$1
    local VISIBILITY=$2
    local DST_NAME=$3

    local SRC_FULL="$SOURCE_ORG/$SRC_NAME"
    local DST_FULL="$DEST_OWNER/$DST_NAME"

    echo "🚀 Migrate: $SRC_FULL -> $DST_FULL"

    echo "  📦 Creating repository ($VISIBILITY)..."
    gh repo create "$DST_FULL" --private --description "Migrated from $SRC_FULL" >/dev/null 2>&1 || { echo "    ⏭️ Repository create error (already exists ?). Ignored." ; return; }

    gh label list --repo "$DST_FULL" --json name -q '.[].name' | while read -r l_name; do
        gh label delete "$l_name" --repo "$DST_FULL" --yes >/dev/null 2>&1
    done
    echo "    ✅ Repository ready."

    echo "  💻 Mirroring code..."
    rm -rf "temp_git_$SRC_NAME"
    git clone --mirror "git@github.com:$SRC_FULL.git" "temp_git_$SRC_NAME" --quiet
    
    if [ -d "temp_git_$SRC_NAME" ]; then
        cd "temp_git_$SRC_NAME" || return
        git remote set-url origin "git@github.com:$DST_FULL.git"
        git push origin --all --quiet >/dev/null 2>&1
        git push origin --tags --quiet >/dev/null 2>&1
        cd ..
        rm -rf "temp_git_$SRC_NAME"
        echo "    ✅ Code mirrored."
    else
        echo "    ❌ Clone failed (Empty repo ?)."
        return
    fi

    echo "  🏷️  Copying labels..."
    gh label list --repo "$SRC_FULL" --limit 100 --json name,color,description | jq -c '.[]' | while read -r label; do
        l_name=$(echo "$label" | jq -r '.name')
        l_color=$(echo "$label" | jq -r '.color')
        l_desc=$(echo "$label" | jq -r '.description')

        if [ "$l_desc" == "null" ]; then
            l_desc=""
        fi

        gh label create "$l_name" \
            --repo "$DST_FULL" \
            --color "$l_color" \
            --description "$l_desc" \
            --force >/dev/null 2>&1
    done

    echo "  🚩 Copying milestones..."
    gh api "repos/$SRC_FULL/milestones?state=all" --paginate | jq -c '.[]' | while read -r m; do
        m_title=$(echo "$m" | jq -r '.title')
        m_desc=$(echo "$m" | jq -r '.description // empty')
        m_due=$(echo "$m" | jq -r '.due_on // empty')
        
        if [ -n "$m_due" ] && [ "$m_due" != "null" ]; then
            gh api "repos/$DST_FULL/milestones" -f title="$m_title" -f description="$m_desc" -f due_on="$m_due" >/dev/null 2>&1
        else
            gh api "repos/$DST_FULL/milestones" -f title="$m_title" -f description="$m_desc" >/dev/null 2>&1
        fi
    done

    echo "  📝 Copying open issues..."
    gh issue list --repo "$SRC_FULL" --state open --limit 1000 --json number,title,body,labels,milestone,url,author,createdAt > "issues_${DST_NAME}.json"
    
    jq -c 'reverse | .[]' "issues_${DST_NAME}.json" | while read -r issue; do
        i_num=$(echo "$issue" | jq -r '.number')
        i_title=$(echo "$issue" | jq -r '.title')
        i_body=$(echo "$issue" | jq -r '.body')
        i_author=$(echo "$issue" | jq -r '.author.login')
        i_url=$(echo "$issue" | jq -r '.url')
        i_date=$(echo "$issue" | jq -r '.createdAt')
        i_milestone=$(echo "$issue" | jq -r '.milestone.title // empty')
        i_labels=$(echo "$issue" | jq -r '.labels[].name' | paste -sd "," -)

        echo "    -----------------------------------"
        echo "    Issue #$i_num: $i_title (by @$i_author)"
            
        read -p "      👉 Copy this issue ? [y/N] " -n 1 -r REPLY_ISSUE < /dev/tty
        echo "" 

        if [[ $REPLY_ISSUE =~ ^[Yy]$ ]]; then
            new_body="$i_body

---

**Migrated Issue**
*Original Author: @$i_author*
*Original Date: $i_date*
*Original Link: $i_url*"

            args=("--repo" "$DST_FULL" "--title" "$i_title" "--body" "$new_body")
            [ -n "$i_labels" ] && args+=("--label" "$i_labels")
            [ -n "$i_milestone" ] && [ "$i_milestone" != "null" ] && args+=("--milestone" "$i_milestone")

            gh issue create "${args[@]}" >/dev/null
        
            sleep 0.5
            echo "      ✅ Copied."
        else
            echo "      ⏭️  Ignored."
        fi
    done
    rm "issues_${DST_NAME}.json"
    echo "    ✅ Issues done."
}


if [ -n "$SPECIFIC_REPO" ]; then
    echo "🎯 Specific repository selected: $SPECIFIC_REPO"
    
    REPO_INFO=$(gh repo view "$SOURCE_ORG/$SPECIFIC_REPO" --json visibility 2>/dev/null)
    
    if [ -z "$REPO_INFO" ]; then
        echo "❌ Error: The repository $SOURCE_ORG/$SPECIFIC_REPO was not found."
        exit 1
    fi
    
    VISIBILITY=$(echo "$REPO_INFO" | jq -r .visibility)
    DEST_NAME=$SPECIFIC_REPO

    if [ "$RENAME_MODE" = true ]; then
        read -p "Rename $SPECIFIC_REPO to (leave empty to keep the same name): " INPUT_NAME
        if [ -n "$INPUT_NAME" ]; then
            DEST_NAME=$INPUT_NAME
        fi
    fi

    process_migration "$SPECIFIC_REPO" "$VISIBILITY" "$DEST_NAME"

else
    echo "📋 Retrieve the list of repositories from $SOURCE_ORG..."
    REPO_LIST=$(gh repo list "$SOURCE_ORG" --no-archived --limit 1000 --json name,visibility)
    echo "Found $(echo "$REPO_LIST" | jq length) repositories."
    
    echo "$REPO_LIST" | jq -c '.[]' | while read -r repo_item; do
        R_NAME=$(echo "$repo_item" | jq -r '.name')
        R_VIS=$(echo "$repo_item" | jq -r '.visibility')
        
        DEST_NAME=$R_NAME
        SHOULD_PROCESS=false

        if [ "$AUTO_YES" = true ]; then
            SHOULD_PROCESS=true
        else
            echo "------------------------------------------------"
            read -p "❓ Clone the repo '$R_NAME' ? [y/N] " RESPONSE < /dev/tty
            if [[ "$RESPONSE" =~ ^[Yy]$ ]]; then
                SHOULD_PROCESS=true
            fi
        fi

        if [ "$SHOULD_PROCESS" = true ]; then
            if [ "$RENAME_MODE" = true ]; then
                read -p "  ✏️  Destination name for '$R_NAME' (Enter = same): " INPUT_NAME < /dev/tty
                if [ -n "$INPUT_NAME" ]; then
                    DEST_NAME=$INPUT_NAME
                fi
            fi

            process_migration "$R_NAME" "$R_VIS" "$DEST_NAME"
        else
            echo "⏭️  Ignored."
        fi
    done
fi

echo "------------------------------------------------"
echo "🎉 Migration completed."