# x9incexc

<!-- TOC -->



<!-- /TOC -->

## Description

`x9incexc` generates a list of files, to a plain text file. This file in turn can be passed to backup programs, rsync, etc., with flags such as `--files-from`.

The reason you would want to use this, is because the native include/exclude syntax of unix-like commands is often arcane if not inscrutible, especially when you want to, say, exclude some file types from some places, but then override that exclusion and include them in certain other places.

Filter declarations can be specified with old-fasioned wildcards, and/or full-featured regex.

The way filter inclusions and exclusions iteratively negate each other is done in an intiutive, stacking manner, which makes much more sense.

The results are output to two files:

- The primary output, to pass to whatever program you need.
- An excluded files list, which is extremely handy for fine-tuning your filters, and is sorely missing from all such utilities that I'm aware of.