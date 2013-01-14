#!/usr/bin/perl

# auto load modules
use Module::Load::Conditional qw[check_install];
use File::Basename;
use Data::Dumper;
use Getopt::Std;

if(check_install(module => 'MP3::Info') ){
    Module::Load::load('MP3::Info');
    $LIST_MP3 = 1;
}

if(check_install(module => 'Ogg::Vorbis::Header') ){
    Module::Load::load('Ogg::Vorbis::Header');
    $LIST_OGG = 1;
}

if(check_install(module => 'Audio::FLAC::Header') ){
    Module::Load::load('Audio::FLAC::Header');
    $LIST_FLAC = 1;
}

# Function prototypes:
sub printFiles($$$$);
sub readFiles($$);
sub getMP3($);
sub getOGG($);
sub getFLAC($);
sub help();
sub init();

############################################################################
# Main

getopts('rl:',\%OPT);

if (@ARGV == 0){
  help();
  exit -1;
}

my $lineend="\n";
init();

print ("#EXTM3U${lineend}"); # print the extended header
my @all;
while(my $mp3root = shift(@ARGV)) {
    $mp3root =~ s/\/$//; #remove trailing slash

    # gather or print the files
    push(@all, readFiles($mp3root,$OPT{'r'}));
}

# randomize output
if($OPT{'r'}){
    fisher_yates_shuffle(\@all);
    foreach my $file (@all){
        printFile($$file[0],$$file[1][0],$$file[1][1],$$file[1][2]);
    }
}


############################################################################
# prints a short Help text
sub help() {
    my $mp3 = $LIST_MP3 ? 'found' : 'NOT found';
    my $ogg = $LIST_OGG ? 'found' : 'NOT found';
    my $fla = $LIST_FLAC ? 'found' : 'NOT found';

print STDERR <<STOP

      Usage: extm3u.pl [-r] [-l LF|CRLF] <music-dir[s]>

      -r           Randomize playlist order (heavy memory use)
      -l           Defines the lineend character(s) to be used
         LF        use linefeed as lineend character (default)
         CRLF      use carriage return + linefeed as lineend characters
      <music-dir>  Search this directory recursivly for audio files

      This tool generates a extended .m3u playlist from a given directory
      for use with XMMS, Winamp (tm) and other music players.
      The playlist is printed to STDOUT. Extended .m3u files contain
      additional informations like length of the song and infos from
      the id3-tag.

      If you give a '-' instead of a directory, it will read music file
      paths from STDIN.

      For running this script you'll need the following Perl modules:

      MP3::Info            for .mp3 files   (module $mp3)
      Ogg::Vorbis::Header  for .ogg files   (module $ogg)
      Audio::FLAC::Header  for .flac files  (module $fla)

      The scripts autodetects which modules are installed. If a module is
      not installed, the corresponding file type is ignored

      _____________________________________________________________________
      extm3u.pl - Generates an extended .m3u mp3-Playlist
      Copyright (C) 2004-2010 Andreas Gohr <andi\@splitbrain.org>

      This program is free software; you can redistribute it and/or
      modify it under the terms of the GNU General Public License as
      published by the Free Software Foundation; either version 2 of
      the License, or (at your option) any later version.

      See COPYING for details
STOP
}


###############################################################################
# get a given FLAC
sub getFLAC($){
    my $file = $_[0];
    my $flac = new Audio::FLAC::Header($file);

    my $sec = int($flac->{trackTotalLengthSeconds});
    my $artist = $flac->tags('ARTIST');
    my $title = $flac->tags('TITLE');

    return [$sec,$artist,$title];
}

###############################################################################
# get a given MP3
sub getMP3($){
    my $file = $_[0];
    my $info = MP3::Info::get_mp3info($file);
    my $tag  = MP3::Info::get_mp3tag($file);

    my $sec    = int($info->{SECS});
    my $artist = $tag->{ARTIST};
    my $title  = $tag->{TITLE};

    return [$sec,$artist,$title];
}

###############################################################################
# get a given OGG
sub getOGG($){
    my $file = $_[0];
    my $ogg  = new Ogg::Vorbis::Header($file);
    return if(!defined($ogg)); # this is no ogg

    my $sec = int($ogg->info->{'length'});

    # this strange construction is to fetch artist and title regardles
    # of tag case
    my ($artist,$title);
    my $tags = join("\n",$ogg->comment_tags());
    if($tags =~ m/^(artist)$/mi){
        $artist =  ($ogg->comment($1))[0];
    }
    if($tags =~ m/^(title)$/mi){
        $title =  ($ogg->comment($1))[0];
    }

    return [$sec,$artist,$title];
}

##############################################################################
# Print extended file info
sub printFile($$$$){
    $file   = $_[0];
    $sec    = $_[1];
    $artist = $_[2];
    $title  = $_[3];

    $base = basename($file,['.mp3','.ogg','.fla','.flac','.wav']);

    if ($artist ne '' || $title ne ''){
        print ("#EXTINF:$sec,$artist - $title${lineend}");
    }else{
        print ("#EXTINF:$sec,$base${lineend}");
    }
    print ("$file${lineend}");
}

##############################################################################
# Read a given directory and its subdirectories
sub readFiles($$) {
    my $path = $_[0];
    my $rand = $_[1];

    my @files;
    if($path eq '-') {
       @files = <STDIN>;
       chomp(@files);
    } else {
       opendir(ROOT, $path);
       @files = map { $path . '/' . $_ } grep { $_ !~ /^\./ } readdir(ROOT);
       closedir(ROOT);
    }

    my @allfiles;

    foreach my $file (sort(@files)) {
        if (-d $file) {
            # recursion
            if($path ne '-') {
               push(@allfiles,readFiles($file,$rand));
            }
        } else {
            # get audio file infos
            my $info = undef;
            if ($LIST_MP3 && $file =~ /\.mp3$/i) {
                $info = getMP3($file);
            } elsif ($LIST_FLAC && $file =~ /\.flac?$/i) {
                $info = getFLAC($file);
            } elsif ($LIST_OGG && $file =~ /\.ogg$/i) {
                $info = getOGG($file);
            } elsif ($file =~ /\.(mp3|flac?|ogg|wav)$/i) { # audio file, but we dont understand it
                $info = [];
            }

            # output file
            if($info){
                if($rand){
                    push(@allfiles,[$file,$info]);
                }else{
                    printFile($file,$$info[0],$$info[1],$$info[2]);
                }
            }
        }
    }
    return @allfiles;
}

# fisher_yates_shuffle( \@array ) : generate a random permutation
# of @array in place
sub fisher_yates_shuffle {
    my $array = shift;
    my $i;
    for ($i = @$array; --$i; ) {
        my $j = int rand ($i+1);
        next if $i == $j;
        @$array[$i,$j] = @$array[$j,$i];
    }
}

# define lineend characters
sub init() {
    if ($OPT{l}) {
    my $opt_parm=uc($OPT{l});
        if ($opt_parm eq 'CRLF') {
        $lineend="\r\n";
        } elsif ($opt_parm eq 'LF') {
        # use the default LF
        } else {
        print STDERR "parameter '${opt_parm}' is unknown for option -l ${lineend}";
            exit -1;
        }
    }
}
