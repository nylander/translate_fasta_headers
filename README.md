translate\_fasta\_headers
=======================

Translate long fasta headers to short - and back!

Your alignment program X doesn't allow strings longer than n characters, but all your info is
in the fasta headers of your file. What to do? Use `translate_fasta_headers.pl` on your fasta file
to create short labels and a translation table. Run your program X, and then back translate your
fasta headers running `translate_fasta_headers.pl` again!

And if you created a tree with the short labels, try to back translate using `replace_taxon_labels_in_newick.pl`!


DESCRIPTION
------------

Replace fasta headers with headers taken from tab delimited file. If no tab file is given,
the (potentially long) fasta headers are replaced by short labels "Seq\_1", "Seq\_2", etc, and
the short and original headers are printed to a translation file.

The script for translating labels in newick trees is somewhat limited in capacity due to the
restrictions of the newick tree format. Use with caution.


USAGE
------

    ./translate_fasta_headers.pl  [--tabfile=<tabfile.tab>]  [--in=<in.fas>]  [--out=<out.fas>]  <in.fas>

    # From long to short labels:
    ./translate_fasta_headers.pl  --out=out.fas  in.fas

    # An back, using a translation table:
    ./translate_fasta_headers.pl  --tabfile=out.fas.translation.tab  out.fas

    # Slightly shorter version (see note about the '--out' option below):
    ./translate_fasta_headers.pl  in.fas  >  out.fas
    ./translate_fasta_headers.pl  -t in.fas.translation.tab  out.fas

    # Translate short seq labels in Newick tree to long
    ./replace_taxon_labels_in_newick.pl  -t out.fas.translation.tab  out.fas.phy


OPTIONS
--------

* `translate_fasta_headers.pl`

    * `-t, --tabfile=<filename>` -- Specify tab-separated translation file with unique "short" labels to the left,
                              and "long" names to the right. Translation will be from left to right.

    * `-o, --out=<filename>`     -- Specify output file for the fasta sequences. Note: If `--out=<filename>` is
                              specified, the translation file will be named `<filename>.translation.tab`.
                              This simplifies back translation. If `--out` is not used, the translation
                              file will be named after the infile!

    * `-i, --in=<filename>`      -- Specify name of fasta file. Can be skipped as script reads files from STDIN.

    * `-n, --notab`              -- Do not create a translation file.

    * `-f, --forceorder`         -- [NOT YET IMPLEMENTED] translate in order of appearance in the fasta file, and use
                              the same order as in the tabfile - without rigid checking of the names! This
                              allows non-unique labels in the left column.

    * `-h, --help`               -- Show this help text and quit.

* `replace_taxon_labels_in_newick.pl`

    * `-t, --table=<translation.tab>` -- file with table describing what will be translated with what.

    * `-h, --help`                    -- Help text.

    * `-o, --out=<out.file>`          -- Print to outfile `out.file`, else to STDOUT.


AUTHOR
-------

Johan.Nylander\@bils.se 


FILES
-----

* translate\_fasta\_headers.pl -- Perl script

* replace\_taxon\_labels\_in\_newick.pl -- Perl script

* in.fas -- example file with long fasta headers

* out.fas.translation.tab -- example translation table

* out.fas -- example output with short fasta headers

* out.fas.phy -- example newick tree with short labels


LICENSE AND COPYRIGHT
---------------------

Copyright (c) 2013, 2014, 2015 Johan Nylander. All rights reserved.

This program is free software; you can redistribute it and/or
modify it under the terms of the GNU General Public License
as published by the Free Software Foundation; either version 2
of the License, or (at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details. 
http://www.gnu.org/copyleft/gpl.html 

