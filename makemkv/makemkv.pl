#!/usr/bin/perl -w

use strict;
no strict qw(vars);
use warnings "all";

use File::Path qw(mkpath);
use File::Copy qw(move);
use Getopt::Long;
use MakeMkv;

#
# Load default settings.
#

{ package Settings; do "makemkv.config"        }
{ package Settings; do "$ENV{HOME}/.makemkvrc" }

my $MAKEMKVCON = $Settings::CFG{'MAKEMKVCON'};
my $HANDBRAKE  = $Settings::CFG{'HANDBRAKE'};
my $SOURCE     = $Settings::CFG{'SOURCE'};
my $MIN_LENGTH = $Settings::CFG{'MIN_LENGTH'};
my $RIP_PATH   = $Settings::CFG{'RIP_PATH'};

my $MAKEMKV;
my %TITLES_TO_RIP;

#
# Load command-line overrides and options.
#

GetOptions
(
    "source=s"      => \$SOURCE     ,
    "min-length=s"  => \$MIN_LENGTH ,
    "info=s"        => \$INFO_FILE  ,
    "atv"           => \$ATV        ,
    "ipad"          => \$IPAD       ,
    "hq"            => \$HQ         ,
    "title-num=s"   => \$TITLE_NUM  ,
    "rip-path=s"    => \$RIP_PATH   ,
    "rip-longest"   => \$RIP_LONGEST,
    "rip-all"       => \$RIP_ALL    ,
    "destination=s" => \$DESTINATION,
);

init();
selectTitles();
prepare();
ripTitles();

#
# Optional MP4 reencoding.
#
#                 Handbrake       Filename
#                 Preset          Suffix
#
mkv2mp4($mkvFile, "AppleTV"     , "atv")  if ($ATV);
mkv2mp4($mkvFile, "iPad"        , "ipad") if ($IPAD);
mkv2mp4($mkvFile, "High Profile", "hq")   if ($HQ);

################################################################################

sub init
{
    $MAKEMKV = MakeMkv->new();

    $MAKEMKV->source($SOURCE);
    $MAKEMKV->makemkvcon($MAKEMKVCON);

    if ($INFO_FILE)
    {
        $MAKEMKV->info($INFO_FILE);
    }
    else
    {
        $MAKEMKV->info();
    }
}

sub prepare
{
    if ($DESTINATION && $RIP_ALL)
    {
        mkpath($DESTINATION);
    }
}

sub queueTitle
{
    my $titleNum = shift;
    my $titles   = $MAKEMKV->getTitles();
    my $mkvFile  = @{$titles}[$titleNum]->mkvFile();
    my $ripFile  = $RIP_PATH . "/" . $mkvFile;
    my $dstFile  = "";

    $TITLES_TO_RIP{$titleNum}->{'MKV_FILE'} = $mkvFile;
    $TITLES_TO_RIP{$titleNum}->{'RIP_FILE'} = $ripFile;
    $TITLES_TO_RIP{$titleNum}->{'DST_FILE'} = $ripFile;

    if ($DESTINATION)
    {
        if ($RIP_ALL)
        {
            $dstFile = $DESTINATION . "/" . $mkvFile;
            $TITLES_TO_RIP{$titleNum}->{'DST_FILE'} = $dstFile;
        }
        elsif ($RIP_LONGEST)
        {
            $dstFile = $DESTINATION;
            $TITLES_TO_RIP{$titleNum}->{'DST_FILE'} = $dstFile;
        }
    }
}

sub selectTitles
{
    my $titles = $MAKEMKV->getTitles();
    die "No titles found" if (@{$titles} == 0);
        
    my $longestTitle = 0;
    LOOP : foreach my $title (@{$titles})
    {
        next LOOP if $title->durationSec() < $MIN_LENGTH;
        printf "Title %d: %s: %3s chapter(s): %s: %7s: %s\n", 
            $title->titleNum(),
            $title->name()    ,
            $title->chapters(),
            $title->duration(),
            $title->size()    ,
            $title->playlist();
        
        if ($title->duration() gt @{$titles}[$longestTitle]->duration())
        {
            $longestTitle = $title->titleNum;
        }
    }
        
    if (defined($TITLE_NUM))
    {
        queueTitle($TITLE_NUM);
    }
    elsif ($RIP_LONGEST)
    {
        queueTitle($longestTitle);
    }
    elsif ($RIP_ALL)
    {
        foreach my $title (@{$titles})
        {
            queueTitle($title->titleNum());
        }
    }
    else
    {
        print "Enter title to rip ('q' to quit): ";
        chomp (my $titleNum = <STDIN>);
        return if ($titleNum eq 'q');

        queueTitle($titleNum);
    }
}

#
# Print a table that lists the available titles on the disc (after filters),
# prompt the user to select a title, and extract that title to MKV format.
#
# @return The full pathname of the newly created MKV file.
#
sub ripTitles
{
    my $titles = $MAKEMKV->getTitles();
    LOOP: foreach my $titleNum (keys %TITLES_TO_RIP)
    {
        # Rip the current title.
        $MAKEMKV->mkv($titleNum, $RIP_PATH);

        # Check for failure.
        if (! -e $TITLES_TO_RIP{$titleNum}->{'RIP_FILE'})
        {
            warn "Failed to create '$TITLES_TO_RIP{$titleNum}->{'RIP_FILE'}'";
            next LOOP;
        }

        # Rename the new mkv file if requested.
        if ($TITLES_TO_RIP{$titleNum}->{'DST_FILE'} ne
            $TITLES_TO_RIP{$titleNum}->{'RIP_FILE'})
        {
            move($TITLES_TO_RIP{$titleNum}->{'RIP_FILE'},
                 $TITLES_TO_RIP{$titleNum}->{'DST_FILE'});
        }
    }
}

#
# Use Handbrake to encode a MKV file in MP4 format.
# 
# @param[in]  mkvFile  Pathname of MKV file to encode.
# @param[in]  preset   Handbrake preset to use for encoding.
# @param[in]  suffix
#     Suffix to add to the MKV filename to create the MP4 filename.
#
sub mkv2mp4
{
    my ($mkvFile, $preset, $suffix) = @_;
    my $mp4File = $mkvFile;
    $mp4File =~ s/\.mkv$/-$suffix\.mp4/g;
    
    my $cmd = join(" ",
    (
        $HANDBRAKE             ,
        "--preset=\"$preset\"" ,
        "--input  \"$mkvFile\"",
        "--output \"$mp4File\"",
    ));

    print "::$cmd\n";
    system($cmd);
}

