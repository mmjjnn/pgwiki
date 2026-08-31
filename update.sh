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

# this should be an absolute path
HTMLDIR=

if [ -z "$HTMLDIR" ]; then
  echo "Error: HTMLDIR must be configured in update.sh" >&2
  exit 1
fi

# Normalize Git URL (SSH or HTTPS) into an HTTPS web viewing URL
WEB_URL="${2%.git}"
if [[ "$WEB_URL" =~ ^git@([^:]+):(.*)$ ]]; then
  WEB_URL="https://${BASH_REMATCH[1]}/${BASH_REMATCH[2]}"
fi

# Given a git repo's web url, how do we get a URL to view or edit specific
# files in a web interface? We append one of the strings below, and then
# append /main/filename.md (except for adding new files, where we append just
# "/main"). TODO: don't hardcode the name of the main branch.
# The below defaults work on GitHub. For GitLab, they should be "-/blob", 
# "-/edit", and "-/new". Other Git web interfaces may use other schemes,
# or not support these operations.
GIT_WEB_VIEW="blob"
GIT_WEB_EDIT="edit"
GIT_WEB_NEW="new"

# Clone or pull the repository
if [ ! -d "$1" ]
then
  git clone -- "$2" "$1"
  cd "$1"
  git config pull.rebase false # avoid noise in logs
else
  cd "$1"
  git pull -- "$2"
fi

# (Re)generate any new or updated pages
mkdir -p "$HTMLDIR/$1"
declare -A title
for page in *.md
do
  # Extract page title as plain text, falling back to the filename if no title
  page_title=$(pandoc --template <(printf '%s' '$title$') -t plain -- "$page")
  title["$page"]="${page_title:-${page%.md}}"

  dest="$HTMLDIR/$1/${page%.md}.html"
  if [ ! -f "$dest" ] || [ "$page" -nt "$dest" ]
  then
    pandoc -f markdown --standalone --mathjax -o "$dest" -- "$page" <(cat <<EOF
----
[View Markdown Source](${WEB_URL}/$GIT_WEB_VIEW/main/$page) --- [Edit in Browser](${WEB_URL}/$GIT_WEB_EDIT/main/$page)
EOF
    )
  fi
done

# Delete any deleted pages
for path in "$HTMLDIR/$1"/*.html
do
  file=${path##*/}
  if [ "$file" = "index.html" ]; then
    continue
  fi
  if [ -f "$path" ] && [ ! -f "${file%.html}.md" ]
  then
    rm -f -- "$path"
  fi
done

# Generate the index
{
  printf "%% Index\n\n"
  for page in "${!title[@]}"
  do
    echo "* [${title[$page]}](${page%.md}.html)"
  done
  printf "\n----\n[View Markdown sources](%s) --- [Add new page](%s/%s/main)\n" \
    "${WEB_URL}" "${WEB_URL}" "$GIT_WEB_NEW"
} | pandoc -f markdown --standalone -o "$HTMLDIR/$1/index.html"
