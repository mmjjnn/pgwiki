#!/bin/bash

# Update a site to current Markdown sources
# Mark Nelson, 2021

# Arguments:
#   $1: the subdirectory to put the site into
#   $2: the GitHub URL where the source lives
# Note that we must be able to clone/pull from $2, either because it's public,
# or because the user running the CGI script has appropriate credentials.

shopt -s nullglob

# this should be an absolute path
HTMLDIR=

# Given a git repo's HTTPS url, how do we get a URL to view or edit specific
# files in a web interface? We chop off the .git extension, then append one of the
# strings below, and then append main/filename.md (except for adding new files,
# where we append just "main"). TODO: don't hardcode the name of the main
# branch.
# The below defaults work on GitHub. For GitLab, they should be "-/blob/", 
# "-/edit/", and "-/new/". Other Git web interfaces may use other schemes,
# or not support these operations.
GIT_WEB_VIEW="blob/"
GIT_WEB_EDIT="edit/"
GIT_WEB_NEW="new/"

# Clone or pull the repository
if [ ! -d "$1" ]
then
  git clone "$2" "$1"
  cd "$1"
  git config pull.rebase false # avoid noise in logs
else
  cd "$1"
  git pull "$2"
fi

# (Re)generate any new or updated pages
mkdir -p "$HTMLDIR/$1"
declare -A title
for page in *.md
do
  # Grab the page title out of the pandoc AST.
  # The AST splits strings into an array of objects, so we have to join them
  # back together. E.g. "Two words" looks like:
  #   [ { "t": "Str", "c": "Two" }, { "t": "Space" }, { "t": "Str", "c": "words" } ]
  title["$page"]=$(pandoc -t json "$page" | jq -r '.meta.title.c | map(if .t=="Space" then " " else .c end) | join("")')

  dest="$HTMLDIR/$1/${page%.md}.html"
  if [ ! -f "$dest" ] || [ "$page" -nt "$dest" ]
  then
    pandoc -f markdown --standalone --mathjax -o "$dest" "$page" <(cat <<EOF
----
[View Markdown Source](${2%.git}/$GIT_WEB_VIEW/main/$page) --- [Edit in Browser](${2%.git}/$GIT_WEB_EDIT/main/$page)
EOF
    )
  fi
done

# Delete any deleted pages
for path in "$HTMLDIR/$1/"/*
do
  file=${path##*/}
  if [ ! -f "${file%.html}.md" ]
  then
    rm "$path"
  fi
done

# Generate the index
{
  printf "%% Index\n\n"
  for page in "${!title[@]}"
  do
    echo "* [${title[$page]}](${page%.md}.html)"
  done
  printf "\n----\n[View Markdown sources](${2%.git}) --- [Add new page](${2%.git}/$GIT_WEB_NEW/main)\n"
} | pandoc -f markdown --standalone -o "$HTMLDIR/$1/index.html"
