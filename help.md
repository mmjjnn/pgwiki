% Wiki help

How this wiki system works:

Each page is a Markdown file with an .md extension. (There shouldn't be spaces
in the filename.)

Extended [Pandoc Markdown](https://pandoc.org/MANUAL.html#pandocs-markdown) is
supported, including math between single or double dollar signs,
syntax-highlighted code blocks, etc.

A table of contents is automatically generated.

To link to other pages in the wiki, link to the .md file, e.g.
[index.md](index.md). This will be rewritten to point to .html in the generated
HTML. FIXME: Not yet implemented!

There are two ways to edit a page:

* Click "edit" on GitHub and edit an .md file in the browser.
* Make edits on your machine in a checked out copy of the repo, and push the
  commits to GitHub.
  * Remember to do a 'git pull' before editing, to make sure you're editing an
    up-to-date copy!

When new edits are made in GitHub, a CGI script on the hosting server is
pinged, which regenerates the HTML files, so edits should be live within a few
seconds.

This setup means that user authentication, resolving edit conflicts, etc. is
all handled by GitHub.

TODOs:

* Currently it's a "flat" wiki: all .md files need to be in the root directory.
  Should add support for organizing pages into subdirectories.
* Pandoc Markdown supports citations in a few different ways. Should pick one
  and set up a reasonable workflow for them.
