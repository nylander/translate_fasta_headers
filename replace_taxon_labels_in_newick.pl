#!/usr/bin/env perl
#===============================================================================
=pod

=head1 NAME

replace_taxon_labels_in_newick.pl - extract or replace taxon labels in Newick

=head1 SYNOPSIS

B<replace_taxon_labels_in_newick.pl> -t F<translation.tab> [options] F<treefile(s)>

=head1 DESCRIPTION

Replaces taxon labels in Newick string with new ones as defined in tab
separated, two-column file F<translation.tab>.

Tree is assumed to be in Newick format and on one single line. If spaces are
discovered in taxon labels, the whole label string is enclosed in single ticks
in order for other software to read the output tree. If, on the other hand,
single ticks are already present in the labels, extra ticks will not be added
and a warning will be issued. Please check the output carefully in that case
(and make sure to remove your single ticks manually if needed).

If the labels to be replaced contain special symbols, replacement with reqular
expressions can be tricky. The script tries to account for these cases by using
(default) "quotemeta" (L<https://perldoc.perl.org/functions/quotemeta>). This
behaviour can be turned off by using B<--no-quote-meta>.  Please check the
output carefully in cases where you have non-standard symbols in the labels.

Format for F<translation.tab> needs to be tab separated, two columns.
Example:

    from_name1 to_name1
    from_name2 to_name2
    from_name3 to_name3

As an alternative to providing the tab separated list as a separate file, you
might add the (tab separated) list to the end of this script!

    $ cp replace_taxon_labels_in_newick.pl repl.pl
    $ cat translation.tab >> repl.pl
    $ ./repl.pl tree.tre

=head1 OPTIONS

=over 4

=item B<-t, --tabfile> F<translation.tab>

File with table describing what will be translated with what. See DESCRIPTION below for format.

=item B<--no-quotemeta>

Turn off escaping of special symbols in the replacements.

=item B<-l,-p, --labels>

Print taxon labels in tree. Option does not require a translation table.

=item B<-v, --version>

Print version.

=item B<-o, --out> F<file.out>

Print to outfile F<file.out>, else to STDOUT.

=item B<-h, --help>

Help text.

=back

=head1 VERSION

1.1

=head1 AUTHOR

Johan Nylander, E<lt>nylander@E<gt>

=head1 DOWNLOAD

L<https://github.com/nylander/translate_fasta_headers>

=head1 COPYRIGHT AND LICENSE

Copyright (c) 2019-2024 Johan Nylander

Permission is hereby granted, free of charge, to any person
obtaining a copy of this software and associated documentation
files (the "Software"), to deal in the Software without
restriction, including without limitation the rights to use,
copy, modify, merge, publish, distribute, sublicense, and/or
sell copies of the Software, and to permit persons to whom the
Software is furnished to do so, subject to the following
conditions:

The above copyright notice and this permission notice shall be
included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES
OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT
HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY,
WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR
OTHER DEALINGS IN THE SOFTWARE.

=cut

#===============================================================================

use strict;
use warnings;
use Getopt::Long;

## Globals
my %header_hash = (); # Key: short, value: long.
my $PRINT;            # Print file handle. Using the typeglob notation below
my $IN;               # in order to use STDOUT as a variable.
my $tabfile       = q{};
my $out           = q{};
my $labels        = q{};
my $use_quotemeta = 1;
my $version       = '1.1'; # also in pod

## Arguments
exec("perldoc", $0) unless (@ARGV);

GetOptions(
    "tabfile=s" => \$tabfile,
    "out=s" => \$out,
    "quotemeta!" => \$use_quotemeta,
    "l|print-labels" => \$labels,
    "version" => sub { print "$version\n"; exit(0); },
    "help" => sub { exec("perldoc", $0); exit(0); },
);

## If tabfile, read it assuming "short" labels in the left column
if ($labels) {
    # print labels
}
else {
    if ($tabfile) {
        %header_hash = read_tabfile($tabfile);
    }
    elsif (<DATA>) {
        %header_hash = read_DATA();
    }
    else {
        print STDERR "Error! No tabfile specified. See $0 -h for usage.\n";
        exit(0);
    }
}

## If outputfile
if ($out) {
    open ($PRINT, '>', $out) or die "$0 : Failed to open output file $out : $!\n\n";
}
else {
    $PRINT = *STDOUT; # Using the typeglob notation in order to use STDOUT as a variable
}

## Read tree files
while (my $treefile = shift(@ARGV)) {
    open my $TREEFILE, "<", $treefile or die "Could not open file: $treefile, $! \n";
    my $notree = 1;
    while (<$TREEFILE>) {
        my $line = $_;
        chomp($line);
        if ($line =~ /^\s*\((\S|\s)+\s*;/) {
            $notree = 0;
            $line = trim_white_space($line);
            if ($labels) {
                print_taxon_labels($line);
            }
            else {
                my $tree = replace_taxon_labels($line, \%header_hash);
                print $PRINT $tree, "\n";
            }
        }
    }
    close ($TREEFILE);
    if ($notree) {
        die "Error: Tried to look for tree in Newick format (tree description on single line) but didn't find it.\n";
    }
}


sub print_taxon_labels {

    #===  FUNCTION  ================================================================
    #         NAME:  print_taxon_labels
    #      VERSION:  Mon 15 apr 2024 09:05:54
    #  DESCRIPTION:  Print taxon labels in tree to STDOUT
    #   PARAMETERS:  string with newick description
    #      RETURNS:  prints
    #         TODO:  Take into account cases where we have quoted taxon labels with
    #                commas, parantheses, etc.
    #===============================================================================

    my ($tree) = @_;
    my (@arr) = split /,/, $tree;
    foreach my $string (@arr) {
        $string =~ s/:.*$//;
        $string =~ s/^[\(]*//;
        print $PRINT $string, "\n";
    }

} # end of print_taxon_labels


sub read_tabfile {

    #===  FUNCTION  ================================================================
    #         NAME:  read_tabfile
    #      VERSION:  09/18/2015 11:52:22 AM
    #  DESCRIPTION:  read tabfile and return hash. Pad strings if they contain white space.
    #   PARAMETERS:  filename
    #      RETURNS:  hash (key:short, value:long)
    #         TODO:  Handle/replace single ticks?
    #===============================================================================

    my ($file) = @_;

    my $found_space_in_short = 0;
    my $found_space_in_long  = 0;
    my %hash                 = (); # Key: short, value: long
    my %return_hash          = (); # Key: short, value: long

    open my $TAB, "<", $file or die "Could not open $file for reading : $! \n";
    while(<$TAB>) {
        chomp;
        next if (/^\s+$/);
        my ($short, $long) = split /\t/, $_;
        $short = trim_white_space($short);
        if (($short =~ /'/) && ($short =~ /\s/)) {
            print STDERR "Warning. Check output format. Found both spaces and single ticks in label:\n  $short\n";
            $found_space_in_short = 1;
        }
        elsif ($short =~ /\s/) {
            $found_space_in_short = 1;
        }
        $long = trim_white_space($long);
        if (($long =~ /'/) && ($long =~ /\s/)) {
            print STDERR "Warning. Check output format. Found both spaces and single ticks in label:\n  $long\n";
            $found_space_in_long = 1;
        }
        elsif ($long =~ /\s/) {
            $found_space_in_long = 1;
        }
        if ($hash{$short}++) {
            die "Warning, the values in the left column of the tabfile must be unique (I found more than one $short)\n";
        }
        else {
            $hash{$short} = $long;
        }
    }
    close($TAB);

    if (($found_space_in_short) || ($found_space_in_long)) {
        while (my ($s, $l) = each (%hash)) {
            if ($found_space_in_short) {
                $s = "\'" . $s . "\'";
            }
            if ($found_space_in_long) {
                $l = "\'" . $l . "\'";
            }
            $return_hash{$s} = $l;
        }
    }
    else {
        %return_hash = %hash;
    }

    return(%return_hash);

} # end of read_tabfile


sub read_DATA {

    #===  FUNCTION  ================================================================
    #         NAME:  read_DATA
    #      VERSION:  08/22/2017 01:15:31 PM
    #  DESCRIPTION:  read DATA and return hash. Pad strings if they contain white space.
    #   PARAMETERS:  -
    #      RETURNS:  hash (key:short, value:long)
    #         TODO:  Handle/replace single ticks?
    #===============================================================================

    my $found_space_in_short = 0;
    my $found_space_in_long  = 0;
    my %hash                 = (); # Key: short, value: long
    my %return_hash          = (); # Key: short, value: long

    while(<DATA>) {
        chomp;
        next if (/^\s+$/);
        my ($short, $long) = split /\t/, $_;
        $short = trim_white_space($short);
        if (($short =~ /'/) && ($short =~ /\s/)) {
            print STDERR "Warning. Check output format. Found both spaces and single ticks in label:\n  $short\n";
            $found_space_in_short = 1;
        }
        elsif ($short =~ /\s/) {
            $found_space_in_short = 1;
        }
        $long = trim_white_space($long);
        if (($long =~ /'/) && ($long =~ /\s/)) {
            print STDERR "Warning. Check output format. Found both spaces and single ticks in label:\n  $long\n";
            $found_space_in_long = 1;
        }
        elsif ($long =~ /\s/) {
            $found_space_in_long = 1;
        }
        if ($hash{$short}++) {
            die "Warning, the values in the left column of the tabfile must be unique (I found more than one $short)\n";
        }
        else {
            $hash{$short} = $long;
        }
    }

    if (($found_space_in_short) || ($found_space_in_long)) {
        while (my ($s, $l) = each (%hash)) {
            if ($found_space_in_short) {
                $s = "\'" . $s . "\'";
            }
            if ($found_space_in_long) {
                $l = "\'" . $l . "\'";
            }
            $return_hash{$s} = $l;
        }
    }
    else {
        %return_hash = %hash;
    }

    return(%return_hash);

} # end of read_DATA


sub trim_white_space {

    #===  FUNCTION  ================================================================
    #         NAME:  trim_white_space
    #      VERSION:  03/14/2013 09:44:02 PM
    #  DESCRIPTION:  trim white space from both ends of string 
    #   PARAMETERS:  string
    #      RETURNS:  string
    #         TODO:  ?
    #===============================================================================

    my ($a) = @_;

    $a =~ s/^\s+//;
    $a =~ s/\s+$//;

    return($a);

} # end of trim_white_space


sub replace_taxon_labels {

    #===  FUNCTION  ================================================================
    #         NAME:  replace_taxon_labels
    #      VERSION:  08/22/2017 01:45:06 PM
    #  DESCRIPTION:  replaces strings with new sequence (taxon) labels
    #   PARAMETERS:  (newick) tree string and reference to hash holding translation table.
    #      RETURNS:  tree string with seq labels replaced
    #         NOTE:  No spaces between label and separators, and most probably no
    #                special characters in taxlabels are allowed.
    #                Quotemeta is mostly untested (tis 16 apr 2024 16:39:50)
    #===============================================================================

    my ($tree, $hash_reference) = @_;

    my $replaced = 0;

    foreach my $string (keys %$hash_reference) { # $key is number, $value is label
        my $newlabel = $hash_reference->{$string};

        if ($use_quotemeta) {
            $string = quotemeta($string);
        }

        if ($tree =~ /,$string:/) {
            $replaced = $tree =~ s/,$string:/,$newlabel:/;      # ',123:' => ',foo:'
        }
        elsif ($tree =~ /\($string:/) {
            $replaced = $tree =~ s/\($string:/\($newlabel:/;    # '(123:' => '(foo:'
        }
        elsif ($tree =~ /\($string,/) {
            $replaced = $tree =~ s/\($string,/\($newlabel,/;    # '(123,' => '(foo,'
        }
        elsif ($tree =~ /,$string,/) {
            $replaced = $tree =~ s/,$string,/,$newlabel,/;      # ',123,' => ',foo,'
        }
        elsif ($tree =~ /,$string\)/) {
            $replaced = $tree =~ s/,$string\)/,$newlabel\)/;    # ',123)' => ',foo)'
        }
        else {
            warn "Warning: No substitutions were made for string $string. Check input and output.\n";
        }
    }
    #die "Error: No substitutions were made. Check output.\n" unless ($replaced);

    return $tree;

} # end of replace_taxon_strings

__DATA__
