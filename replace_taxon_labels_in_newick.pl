#!/usr/bin/perl 
#===============================================================================
=pod


=head2

         FILE: replace_taxon_labels_in_newick.pl

        USAGE: ./replace_taxon_labels_in_newick.pl -t translation.tab [-o out.file] treefile(s) 

  DESCRIPTION: Replaces taxon labels in Newick string with new ones as defined in tab separated,
               two-column file translation.tab

      OPTIONS: -t, --table translation.tab.  File with table describing what will be translated
                                             with what. See below for format.

               -h, --help.                   Help text.

               -o, --out out.file.           Print to outfile file.out, else to STDOUT.

 REQUIREMENTS: ---

         BUGS: ---

        NOTES: Tree is assumed to be in Newick format and on one single line.
               If spaces are discovered in taxon labels, the whole label string is enclosed
               in single ticks in order for other software to read the output tree. If,
               on the other hand, single ticks are already present in the labels, extra
               ticks will not be added and a warning will be issued. Please check the output
               carefully in that case (and make sure to remove your single ticks manually).

               Format for translation.tab needs to be tab separated, two columns.
               Example:

                   from_name1 to_name1
                   from_name2 to_name2
                   from_name3 to_name3

               As an alternative to providing the tab separated list as a separate file, you
               might add the (tab separated) list to the end of this script!

                   $ cp replace_taxon_labels_in_newick.pl repl.pl
                   $ cat translation.tab >> repl.pl
                   $ ./repl.pl tree.tre

       AUTHOR: Johan Nylander (JN), johan.nylander@nbis.se

      COMPANY: BILS/NRM

      VERSION: 1.0

      CREATED: 08/26/2015 04:14:19 PM

     REVISION: 08/22/2017 01:14:27 PM

=cut


#===============================================================================

use strict;
use warnings;
use Data::Dumper;
use Getopt::Long;

## Globals
my %header_hash  = (); # Key: short, value: long.
my $PRINT;             # Print file handle. Using the typeglob notation below
my $IN;                # in order to use STDOUT as a variable.
my $tabfile      = q{};
my $out          = q{};
my $VERBOSE      = 0;

## Arguments
exec("perldoc", $0) unless (@ARGV);
my $r = GetOptions("tabfile=s" => \$tabfile,
                   "out=s"     => \$out,
                   "verbose!"  => \$VERBOSE,
                   "help"      => sub { exec("perldoc", $0); exit(0); },
                  );

## If tabfile, read it assuming "short" labels in the left column
if ($tabfile) {
    %header_hash = read_tabfile($tabfile);
}
else {
    if (<DATA>) {
        %header_hash = read_DATA();
    }
    else {
        print STDERR "Error! No tabfile specified. See $0 -h for manual.\n";
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
            my $tree = replace_taxon_labels($line, \%header_hash);
            print $PRINT $tree, "\n";
        }
    }
    close($TREEFILE);
    if ($notree) {
        print STDERR "Error: Tried to look for tree in Newick format (tree description on single line) but didn't find it.\n";
    }
}


#===  FUNCTION  ================================================================
#         NAME:  read_tabfile
#      VERSION:  09/18/2015 11:52:22 AM
#  DESCRIPTION:  read tabfile and return hash. Pad strings if they contain white space.
#   PARAMETERS:  filename
#      RETURNS:  hash (key:short, value:long)
#         TODO:  Handle/replace single ticks?
#===============================================================================
sub read_tabfile {

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


#===  FUNCTION  ================================================================
#         NAME:  read_DATA
#      VERSION:  08/22/2017 01:15:31 PM
#  DESCRIPTION:  read DATA and return hash. Pad strings if they contain white space.
#   PARAMETERS:  -
#      RETURNS:  hash (key:short, value:long)
#         TODO:  Handle/replace single ticks?
#===============================================================================
sub read_DATA {

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


#===  FUNCTION  ================================================================
#         NAME:  trim_white_space
#      VERSION:  03/14/2013 09:44:02 PM
#  DESCRIPTION:  trim white space from both ends of string 
#   PARAMETERS:  string
#      RETURNS:  string
#         TODO:  ????
#===============================================================================
sub trim_white_space {

    my ($a) = @_;

    $a =~ s/^\s+//;
    $a =~ s/\s+$//;

    return($a);

} # end of trim_white_space


#===  FUNCTION  ================================================================
#         NAME:  check_white_space_in_labels
#      VERSION:  09/18/2015 10:54:43 AM
#  DESCRIPTION:  check if white space and/or single ticks in labels. Add single
#                ticks to ends if found white spaces, not if found single ticks.
#                If found single ticks, warn.
#   PARAMETERS:  string
#      RETURNS:  string
#         TODO:  ????
#===============================================================================
sub check_white_space_in_labels {

    my ($string) = @_;

    if ($string =~ /\s/) {
        if ($string =~ /'/) {
            warn "Caution: found single ticks and spaces in taxon labels. Check output format carefully.\n";
        }
        else {
            $string = "\'" . $string . "\'";
        }
    }

    return($string);

} # end of check_white_space_in_labels


#===  FUNCTION  ================================================================
#         NAME:  replace_taxon_labels
#      VERSION:  02/02/2007 01:48:44 AM CET
#  DESCRIPTION:  replaces strings with new sequence (taxon) labels
#   PARAMETERS:  (newick) tree string and reference to hash holding translation table.
#      RETURNS:  tree string with seq labels replaced
#         NOTE:  No spaces between label and separators, and most probably no
#                special characters in taxlabels are allowed.
#===============================================================================
sub replace_taxon_labels {

    my ($tree, $hash_reference) = @_;

    my $replaced = 0;

    foreach my $string (keys %$hash_reference) { # $key is number, $value is label
        my $newlabel = $hash_reference->{$string};
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
        else {
            $replaced = $tree =~ s/,$string\)/,$newlabel\)/;    # ',123)' => ',foo)'
        }
    }
    die "Error: No substitutions were made. Check output.\n" unless ($replaced);

    return $tree;

} # end of replace_taxon_strings

__DATA__
