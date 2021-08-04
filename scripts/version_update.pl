#!/usr/bin/env perl

###############################################################################
 #
 #  This file is part of canu, a software program that assembles whole-genome
 #  sequencing reads into contigs.
 #
 #  This software is based on:
 #    'Canu' v2.0              (https://github.com/marbl/canu)
 #  which is based on:
 #    'Celera Assembler' r4587 (http://wgs-assembler.sourceforge.net)
 #    the 'kmer package' r1994 (http://kmer.sourceforge.net)
 #
 #  Except as indicated otherwise, this is a 'United States Government Work',
 #  and is released in the public domain.
 #
 #  File 'README.licenses' in the root directory of this distribution
 #  contains full conditions and disclaimers.
 ##

use strict;
use File::Compare;
use Cwd qw(getcwd);

my $cwd = getcwd();

#  This script expects a module name on the command line, e.g.,
#  'version-update.pl canu'.  This name is used is the non-git based version
#  string.
#
#  On release change $label to 'release', update $major and $minor.  Make the
#  release, then change label back to 'snapshot'.  This will result in the
#  released code having a version string of "$modName 1.9".

my $modName  = shift @ARGV;
my $MODNAME  = $modName;       $MODNAME =~ tr/a-z-/A-Z_/;

my $verFile  = shift @ARGV;

my $label    = "release";       #  If not 'release' print this in the version output.
my $major    = "2";             #  Bump before release.
my $minor    = "2";             #  Bump before release.

my $version  = "v$major.$minor";

my @submodules;

my $commits  = undef;
my $hash1    = undef;          #  This from 'git describe'
my $hash2    = undef;          #  This from 'git rev-list'
my $revCount = 0;
my $dirty    = undef;
my $dirtya   = undef;
my $dirtyc   = undef;

#  Required module name on the command line.

if (($modName eq "") || ($modName eq undef) || ($verFile eq undef)) {
    die "usage: $0 module-name version-file.H\n";
}

#  If in a git repo, we can get the actual values.

if (-d "../.git") {
    $label = "snapshot";

    #  Count the number of changes since the last release.
    open(F, "git rev-list HEAD |") or die "Failed to run 'git rev-list'.\n";
    while (<F>) {
        chomp;

        $hash2 = $_  if (!defined($hash2));
        $revCount++;
    }
    close(F);

    #  Find the commit and version we're at.
    open(F, "git describe --tags --long --always --abbrev=40 |") or die "Failed to run 'git describe'.\n";
    while (<F>) {
        chomp;
        if (m/^v(\d+)\.(.+)-(\d+)-g(.{40})$/) {
            $major   = $1;
            $minor   = $2;
            $commits = $3;
            $hash1   = $4;

            $version = "v$major.$minor";
        } else {
            $major   = "0";
            $minor   = "0";
            $commits = "0";
            $hash1   = $_;

            $version = "v$major.$minor";
        }
    }
    close(F);

    #  Decide if we've got locally committed changes.
    open(F, "git status |");
    while (<F>) {
        if (m/is\s+ahead\s/) {
            $dirtya = "ahead of github";
        }
        if (m/not\s+staged\s+for\s+commit/) {
            $dirtyc = "uncommitted changes";
        }
    }
    close(F);

    if    (defined($dirtya) && defined($dirtyc)) {
        $dirty = "ahead of github w/changes";
    }
    elsif (defined($dirtya)) {
        $dirty = "ahead of github";
    }
    elsif (defined($dirtyc)) {
        $dirty = "w/changes";
    }
    else {
        $dirty = "sync'd with github";
    }


    #  Figure out which branch we're on.
    {
        my $branch;

        open(F, "git branch --contains |");
        while (<F>) {
            next  if (m/detached\sat/);

            chomp;

            tr/*//d;     #  Remove * from "* master"
            s/^\s+//;    #  Remove spaces.
            s/\s+$//;

            $branch = $_;
            last;
        }
        close(F);

        if ($branch ne "master") {
            if ($branch =~ m/v(\d+)\.(\d+)/) {    #  If we're a release branch, save
                $major = $1;                      #  major and minor versions.
                $minor = $2;
            }

            $label   = "branch";
            $version = $branch;
        }
    }


    #  Get information on any submodules here.
    open(F, "git submodule status |");
    while (<F>) {
        if (m/^(.*)\s+(.*)\s+\((.*)\)$/) {
            push @submodules, "$2 $3 $1";
        }
    }
    close(F);
}


#  If not in a git repo, we might be able to figure things out based on the directory name.

elsif ($cwd =~ m/$modName-(.{40})\/src/) {
    $label   = "snapshot";
    $hash1   = $1;
    $hash2   = $1;
}

elsif ($cwd =~ m/$modName-master\/src/) {
    $label   = "master-snapshot";
}


#  Report what we found.  This is really for the gmake output.

if (defined($commits)) {
    print "\$(info Building $label $version +$commits changes (r$revCount $hash1) ($dirty))\n";
    foreach my $s (@submodules) {
        print "\$(info \$(space)         $s)\n";
    }
} else {
    print "\$(info Building $label $version)\n";
}

#  Dump a new file, but don't overwrite the original.

open(F, "> ${verFile}.new") or die "Failed to open '${verFile}.new' for writing: $!\n";
print F "//  Automagically generated by version_update.pl!  Do not commit!\n";
print F "#define ${MODNAME}_VERSION_LABEL     \"$label\"\n";
print F "#define ${MODNAME}_VERSION_MAJOR     \"$major\"\n";
print F "#define ${MODNAME}_VERSION_MINOR     \"$minor\"\n";
print F "#define ${MODNAME}_VERSION_COMMITS   \"$commits\"\n";
print F "#define ${MODNAME}_VERSION_REVISION  \"$revCount\"\n";
print F "#define ${MODNAME}_VERSION_HASH      \"$hash1\"\n";
print F "\n";

if      (defined($commits)) {
    print F "#define ${MODNAME}_VERSION           \"$modName $label $version +$commits changes (r$revCount $hash1)\\n\"\n";
} elsif (defined($hash1)) {
    print F "#define ${MODNAME}_VERSION           \"$modName snapshot ($hash1)\\n\"\n";
} elsif ($label  =~ m/release/) {
    print F "#define ${MODNAME}_VERSION           \"$modName $major.$minor\\n\"\n";
} else {
    print F "#define ${MODNAME}_VERSION           \"$modName $label ($version)\\n\"\n";
}

if ($MODNAME ne "MERYL_UTILITY") {
    print F "\n";
    print F "#undef  MERYL_UTILITY_VERSION\n";
    print F "#define MERYL_UTILITY_VERSION ${MODNAME}_VERSION\n";
}

close(F);

#  If they're the same, don't replace the original.

if (compare("${verFile}", "${verFile}.new") == 0) {
    unlink "${verFile}.new";
} else {
    unlink "${verFile}";
    rename "${verFile}.new", "${verFile}";
}

#  That's all, folks!

exit(0);

