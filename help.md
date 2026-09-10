% Wiki help

How this wiki system works:

Each page is a Markdown file with an .md extension. Pages can be in the root
directory or organized into subdirectories.

Extended [Pandoc Markdown](https://pandoc.org/MANUAL.html#pandocs-markdown) is
supported, including math between single or double dollar signs,
syntax-highlighted code blocks, etc.

A table of contents is automatically generated.

To link to other pages in the wiki, link to the .md file, e.g.
[index.md](index.md). This will be rewritten to point to .html in the generated
HTML. FIXME: Not yet implemented!

Citations to BibTeX files are supported (pandoc also supports other
bibliography formats, but we only implement BibTeX for now). Keys in any `.bib`
file in the wiki root can be cited from any page on the wiki, using Markdown
`[@keyname]` style citations.

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
