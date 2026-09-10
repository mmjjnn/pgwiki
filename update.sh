#!/bin/bash

# Update a site to current Markdown sources
# Mark Nelson, 2021, 2026

# Arguments:
#   $1: the subdirectory to put the site into
#   $2: the GitHub URL where the source lives
# Note that we must be able to clone/pull from $2, either because it's public,
# or because the user running the CGI script has appropriate credentials.

set -euo pipefail
shopt -s nullglob

# Validate arguments
if [ $# -lt 2 ] || [ -z "$1" ] || [ -z "$2" ]; then
  echo "Usage: $0 <wiki-subdir> <git-url>" >&2
  exit 1
fi
if [[ "$1" =~ \.\. ]] || [[ "$1" =~ ^/ ]]; then
  echo "Error: Invalid wiki directory name: $1" >&2
  exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONF_FILE="$SCRIPT_DIR/update.conf"

if [ ! -f "$CONF_FILE" ]; then
  echo "Error: Configuration file '$CONF_FILE' not found." >&2
  exit 1
fi

# shellcheck source=/dev/null
. "$CONF_FILE"

if [ -z "${HTMLDIR:-}" ]; then
  echo "Error: HTMLDIR must be configured in update.conf" >&2
  exit 1
fi
HTMLDIR="${HTMLDIR%/}"

# Find SSH deploy key for private repositories
KEYDIR="${KEYDIR:-$SCRIPT_DIR}"
KEYFILE="${KEYDIR}/key_${1}"
KNOWN_HOSTS="${KEYDIR}/known_hosts"

if [ -f "$KEYFILE" ]; then
  ssh_opts=(-i "$KEYFILE")
  if [ -f "$KNOWN_HOSTS" ]; then
    ssh_opts+=(-o "UserKnownHostsFile=$KNOWN_HOSTS")
  else
    ssh_opts+=(-o "StrictHostKeyChecking=accept-new")
  fi
  export GIT_SSH_COMMAND="ssh ${ssh_opts[*]}"
fi

# Normalize Git URL (SSH or HTTPS) into an HTTPS web viewing URL
WEB_URL="${2%.git}"
if [[ "$WEB_URL" =~ ^git@([^:]+):(.*)$ ]]; then
  WEB_URL="https://${BASH_REMATCH[1]}/${BASH_REMATCH[2]}"
fi

# Given a git repo's web url, how do we get a URL to view or edit specific
# files in a web interface? We append one of the strings below, and then
# append /$BRANCH/filename.md (except for adding new files, where we append
# just "/$BRANCH").
# The below defaults work on GitHub. For GitLab, they should be "-/blob", 
# "-/edit", and "-/new". Other Git web interfaces may use other schemes,
# or not support these operations.
GIT_WEB_VIEW="blob"
GIT_WEB_EDIT="edit"
GIT_WEB_NEW="new"

# Clone or sync the repository
if [ ! -d "$1" ]
then
  git clone -- "$2" "$1"
  cd "$1"
else
  cd "$1"
  git remote set-url origin "$2"
  git fetch --prune origin
fi

# Get branch name or default to "main"
BRANCH=$(git symbolic-ref --short HEAD 2>/dev/null || echo "main")

# Reset to origin to avoid any possibility of merge conflicts
# (This should be a pull-only clone.)
if git show-ref --verify --quiet "refs/remotes/origin/$BRANCH"; then
  git reset --hard "origin/$BRANCH"
fi

# (Re)generate any new or updated pages
mkdir -p "$HTMLDIR/$1"
declare -A title

# Discover any .bib files in the wiki root
bib_args=()
bib_files=(*.bib)
if [ ${#bib_files[@]} -gt 0 ]; then
  bib_args+=(--citeproc --metadata link-citations=true)
  for bib in "${bib_files[@]}"; do
    bib_args+=(--bibliography="$PWD/$bib")
  done
fi

while IFS= read -r -d '' page; do
  relpath="${page#./}"

  # Ignore root index.md as index.html is reserved for the auto-generated ToC
  if [ "$relpath" = "index.md" ]; then
    continue
  fi

  # Extract page title as plain text, falling back to the filename basename if no title
  bname="${relpath##*/}"
  page_title=$(pandoc --template <(printf '%s' '$title$') -t plain -- "$page")
  title["$relpath"]="${page_title:-${bname%.md}}"

  dest="$HTMLDIR/$1/${relpath%.md}.html"
  dest_dir="${dest%/*}"
  mkdir -p -- "$dest_dir"

  rebuild=0
  if [ ! -f "$dest" ] || [ "$page" -nt "$dest" ]; then
    rebuild=1
  else
    for bib in "${bib_files[@]}"; do
      if [ "$bib" -nt "$dest" ]; then
        rebuild=1
        break
      fi
    done
  fi

  if [ "$rebuild" -eq 1 ]; then
    pandoc -f markdown --standalone --mathjax "${bib_args[@]}" \
      --include-after-body=<(cat <<EOF
<hr>
<p><a href="${WEB_URL}/$GIT_WEB_VIEW/$BRANCH/$relpath">View Markdown Source</a> &mdash; <a href="${WEB_URL}/$GIT_WEB_EDIT/$BRANCH/$relpath">Edit in Browser</a></p>
EOF
      ) \
      -o "$dest" -- "$page"
  fi
done < <(find . -name .git -prune -o -name ".*" ! -name . -prune -o -type f -name "*.md" -print0)

# Copy new or updated static assets (including in subdirectories)
find . -name .git -prune -o -name ".*" ! -name . -prune -o -type f ! -name "*.md" ! -name "*.html" -print0 | while IFS= read -r -d '' file; do
  relpath="${file#./}"
  dest="$HTMLDIR/$1/$relpath"
  dest_dir="${dest%/*}"
  mkdir -p -- "$dest_dir"
  if [ ! -f "$dest" ] || [ "$file" -nt "$dest" ]; then
    cp -p -- "$file" "$dest"
  fi
done

# Delete any deleted pages
if [ -d "$HTMLDIR/$1" ]; then
  find "$HTMLDIR/$1" -type f -name "*.html" -print0 | while IFS= read -r -d '' dest_file; do
    relpath="${dest_file#$HTMLDIR/$1/}"
    if [ "$relpath" = "index.html" ]; then
      continue
    fi
    if [ ! -f "${relpath%.html}.md" ]; then
      rm -f -- "$dest_file"
    fi
  done
fi

# Delete any deleted static assets and cleanup empty directories
if [ -d "$HTMLDIR/$1" ]; then
  find "$HTMLDIR/$1" -type f ! -name "*.html" -print0 | while IFS= read -r -d '' dest_file; do
    relpath="${dest_file#$HTMLDIR/$1/}"
    if [ ! -f "$relpath" ]; then
      rm -f -- "$dest_file"
    fi
  done
  find "$HTMLDIR/$1" -depth -type d ! -path "$HTMLDIR/$1" -exec rmdir {} + 2>/dev/null || true
fi

# Generate the index
{
  printf "%% Index\n\n"
  prev_dir=""
  while IFS= read -r page; do
    [ -n "$page" ] || continue
    dir="${page%/*}"
    [ "$dir" = "$page" ] && dir=""

    # If the directory changed, emit any newly entered directory levels
    if [ "$dir" != "$prev_dir" ]; then
      IFS='/' read -r -a cur_parts <<< "$dir"
      IFS='/' read -r -a prev_parts <<< "$prev_dir"
      [ -z "$dir" ] && cur_parts=()
      [ -z "$prev_dir" ] && prev_parts=()

      common=0
      while [ $common -lt ${#cur_parts[@]} ] && [ $common -lt ${#prev_parts[@]} ] && [ "${cur_parts[$common]}" = "${prev_parts[$common]}" ]; do
        ((common++))
      done

      for ((i=common; i<${#cur_parts[@]}; i++)); do
        indent=$(printf "%$((i * 2))s" "")
        echo "${indent}* ${cur_parts[$i]}/"
      done
      prev_dir="$dir"
    fi

    # Print the page link indented under its directory
    IFS='/' read -r -a cur_parts <<< "$dir"
    [ -z "$dir" ] && cur_parts=()
    indent=$(printf "%$((${#cur_parts[@]} * 2))s" "")
    echo "${indent}* [${title[$page]}](${page%.md}.html)"
  done < <(printf '%s\n' "${!title[@]}" | sort -f)

  printf "\n----\n[View Markdown sources](%s) --- [Add new page](%s/%s/%s)\n" \
    "${WEB_URL}" "${WEB_URL}" "$GIT_WEB_NEW" "$BRANCH"
} | pandoc -f markdown --standalone -o "$HTMLDIR/$1/index.html"
