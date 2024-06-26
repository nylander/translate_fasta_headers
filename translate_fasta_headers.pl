#!/usr/bin/env perl
#===============================================================================
=pod

=head1 NAME

translate_fasta_headers.pl - translate fasta headers from long to short -- and back!

=head1 SYNOPSIS

B<translate_fasta_headers.pl> [options] F<file>

=head1 DESCRIPTION

Replace fasta headers with headers taken from tab delimited file.  If no tab
file is given, the (potentially long) fasta headers are replaced by short
labels "Seq_1", "Seq_2", etc, and the short and original headers are printed to
a translation file.

=head1 OPTIONS

=over 4

=item B<-t, --tabfile>=F<filename>

Specify tab-separated translation file with unique "short" labels to the left,
and "long" names to the right. Translation will be from left to right.

=item B<-i, --in>=F<filename>

Specify name of fasta file. Can be skipped as script reads files from STDIN.

=item B<-o, --out>=F<filename>

Specify output file for the fasta sequences.  Note: If b<--out>=F<filename> is
specified, the translation file will be named F<filename>.translation.tab. This
simplifies back translation. If B<--out> is not used, the translation file will
be named after the infile!

=item B<-n, --notab>

Do not create a translation file.

=item B<-p, --prefix>=I<string>

Prefix for short label. Defaults to I<Seq_>.

=item B<-v, --version>

Print version number and quit.

=item B<-h, --help>

Show this help text and quit.

=back

=head1 VERSION

1.1

=head1 AUTHOR

Johan Nylander

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
my $prefix       = 'Seq_'; # Prefix for short names
my $version      = '1.1'; # Also in pod
my $tabfile      = q{};
my $in           = q{};
my $out          = q{};
my $notab        = q{};
my $help         = q{};
my %header_hash  = ();     # Key: short, value: long.
my @short_array  = ();     # Array with short headers.
my @long_array   = ();     # Array with long headers.
my $PRINT;                 # Print file handle. Using the typeglob notation below
my $IN;                    # in order to use STDOUT as a variable.
#my $forceorder   = q{};

## If no arguments
exec("perldoc", $0) unless (@ARGV);

## Get args
GetOptions(
    "tabfile|translationfile=s" => \$tabfile,
    "out=s"                     => \$out,
    "notab"                     => \$notab,
    "in=s"                      => \$in,
    "prefix=s"                  => \$prefix,
    #"forceorder"                => \$forceorder,
    "version"                   => sub { print "$version\n"; exit(0); },
    "help"                      => sub { exec("perldoc", $0); exit(0); },
);

## If tabfile, read it assuming "short" labels in the left column
if ($tabfile) {
    %header_hash = read_tabfile($tabfile);
}

## If outputfile
if ($out) {
    open ($PRINT, '>', $out) or die "$0 : Failed to open output file $out : $!\n\n";
}
else {
    $PRINT = *STDOUT; # Using the typeglob notation in order to use STDOUT as a variable
}

## If infile
if ($in) {
    read_infile($in, $prefix);
}
else {
    while (my $infile = shift(@ARGV)) {
        read_infile($infile, $prefix);
    }
}

exit(0);


sub read_infile {

    #===  FUNCTION  ================================================================
    #         NAME:  read_infile
    #      VERSION:  01/10/2018 01:03:55 PM
    #  DESCRIPTION:  Reads a tab separated file and returns a hash. Expects all values
    #                in left column ("short") to be unique!
    #   PARAMETERS:  filename, prefix
    #      RETURNS:  hash: key:short, value:long
    #         TODO:
    #===============================================================================

    my ($file, $shortlabel) = (@_);
    my @in_headers_array    = ();
    my $counter             = 1;
    my $OUTTAB;
    my $outtabfile;

    ## Name translation.file from out if available. Saves time with back translation...
    if ($out) {
        $outtabfile = $out . '.translation.tab';
    }
    else {
        $outtabfile = $file . '.translation.tab';
    }

    open my $IN, "<", $file or die "Could not open $file for reading : $! \n";

    ## Open tab translation outfile or not
    if ($tabfile) {
        # not open
    }
    elsif ($notab) {
        # not open
    }
    else {
        if ( -e $outtabfile ) {
            die "\nCovardly refusing to overwrite existing $outtabfile . Rename files of use \'--notab\'.\n\n";
        }
        else {
            open $OUTTAB, ">", $outtabfile or die "Could not open $outtabfile for writing : $! \n";
        }
    }

    ## Read fasta file
    while(<$IN>) {
        my $line = $_;
        chomp($line);
        if ($line =~ /^\s*>/) {
            $line =~ s/^\s*>//;
            $line = trim_white_space($line);
            if ($tabfile) {
                if (exists $header_hash{$line}) {
                    print $PRINT '>', $header_hash{$line}, "\n";
                }
                else {
                    die "\nLabel \"$line\" in $file not found in $tabfile.\n";
                }
            }
            else {
                my $header = $shortlabel . $counter;
                print $PRINT '>', $header, "\n";
                print($OUTTAB $header, "\t", $line, "\n") unless $notab;
                $counter++;
            }
        }
        else {
            print $PRINT $line, "\n";
        }
    }
    close($IN);
    #close($OUTTAB); # Let garbage collector do some work

} # end of read_infile


sub read_tabfile {

    #===  FUNCTION  ================================================================
    #         NAME:  read_tabfile
    #      VERSION:  03/14/2013 09:42:47 PM
    #  DESCRIPTION:  read tabfile and return hash
    #   PARAMETERS:  filename
    #      RETURNS:  hash (key:short, value:long)
    #         TODO:  ????
    #===============================================================================

    my ($file) = @_; 

    my %hash = (); # Key: short, value: long

    open my $TAB, "<", $file or die "Could not open $file for reading : $! \n";
    while(<$TAB>) {
        chomp;
        next if (/^\s*$/);
        my ($short, $long) = split /\t/, $_;
        $short = trim_white_space($short);
        $long = trim_white_space($long);
        if ($hash{$short}++) {
            die "Warning, the values in the left column of the tabfile must be unique (I found more than one $short)\n";
        }
        else {
            $hash{$short} = $long;
        }
    }
    close($TAB);

    return(%hash);

} # end of read_tabfile


sub trim_white_space {

    #===  FUNCTION  ================================================================
    #         NAME:  trim_white_space
    #      VERSION:  03/14/2013 09:44:02 PM
    #  DESCRIPTION:  trim white space from both ends of string 
    #   PARAMETERS:  string
    #      RETURNS:  string
    #         TODO:  ????
    #===============================================================================

    my ($a) = @_;

    $a =~ s/^\s+//;
    $a =~ s/\s+$//;

    return($a);

} # end of trim_white_space

