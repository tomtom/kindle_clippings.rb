Introduction
============

This is a simple ruby script to convert kindle clippings / notes / 
highlights to plain text (or viki markup).

For now, only Kindle version 2 (e.g. Kindle DX) clipping files are 
supported (i.e. tested). I have no idea if the script works for other 
versions.

Example usage:

    kindle_clippings.rb --dir ~/MyClips /media/kindle/My\\ Clippings.txt


Installation
============

Copy or symlink `kindle_clippings.rb` to a directory in $PATH.


Configuration
=============

The script can be configured via YAML files that is searched in:
- `/etc/kindle_clippings.yml`
- `$HOME/.kindle_clippings.yml`
- `$HOME/.kindle_clippings_$HOSTNAME.yml`
- `Windows: %USERPROFILE%/kindle_clippings.yml`

Example configuration file:

    --- 
    format: viki
    outdir: /home/tom/Wiki/KindleNotes
    myclippings: /home/tom/sync/Kindle/My Clippings.txt


Requirements
============

- Ruby 1.8

