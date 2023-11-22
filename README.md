# Presto-Iceberg Workshop

This is a repo that hosts the materials for the Presto-Iceberg workshop. You can view the workshop
[here](https://ibm.github.io/presto-iceberg-lab/)

Here is the file structure of this repo:

```ini
+-- conf (configuration and other files needed to start containers)
+-- data (any data (CSV, JSON, etc files) to be used)
+-- docs (this is where the workshop is documented)
|   +-- <folder-n> (these are exercises for the workshop)
    |   +-- README.md (the steps for the exercise, in Markdown)
|   +-- README.md (this will appear on the gitbook home page)
|   +-- src (any application source code can go here)
+-- .mkdocs.yaml (configuration for mkdocs)
+-- .travis.yaml (runs markdownlint by default)
+-- README.md (only used for GitHub.com)
```

## Authors

- Kiersten Stokes kiersten.stokes@ibm.com
