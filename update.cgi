#!/bin/bash

# CGI script to update when Markdown source changes (to be called from a
# post-commit hook).
# Mark Nelson, 2021, 2026

# SCRIPTDIR should be a directory that is not publicly served over HTTP, but
# can be written to by the user running CGI scripts (often 'web').
SCRIPTDIR=

# Associative array of subdirectory -> git URL
# This script expects a single query parameter, "wiki=wikiname", where wikiname
# matches one of the wikis defined below.
declare -A wikis
wikis[example]="https://github.com/NelsonAU/example.git"

echo "Content-type: text/plain"

if [ -z "$SCRIPTDIR" ] || [ ! -d "$SCRIPTDIR" ]; then
  echo "Status: 500 Internal Server Error"
  echo ""
  echo "SCRIPTDIR undefined or does not exist."
  exit 0
fi

if [[ ${QUERY_STRING:-} =~ (^|&)wiki=([a-zA-Z0-9_-]+)(&|$) ]]
then
  wiki="${BASH_REMATCH[2]}"
  if [ -n "${wikis[$wiki]:-}" ]
  then
    echo ""
    echo "Updating $wiki from ${wikis[$wiki]}"
    if ! cd "$SCRIPTDIR"; then
      echo "Status: 500 Internal Server Error"
      echo ""
      echo "Failed to change directory to SCRIPTDIR."
      exit 0
    fi
    ./update.sh "$wiki" "${wikis[$wiki]}"
  else
    echo "Status: 422 Invalid parameter"
    echo ""
    echo "Unknown wiki: $wiki"
  fi
else
  echo "Status: 422 Invalid parameter"
  echo ""
  echo "Missing or invalid query string: \"${QUERY_STRING:-}\""
  echo "Expected: wiki=wikiname"
fi
