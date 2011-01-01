#!/usr/bin/perl

# auto load modules
use Module::Load::Conditional qw[check_install];

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
sub readFiles($);
sub printMP3($$);
sub printOGG($$);
sub printFLAC($$);
sub help();


############################################################################
# Main

if (@ARGV != 1){
  help();
  exit -1;
}

my $mp3root = $ARGV[0];
$mp3root =~ s/\/$//; #remove trailing slash
print ("#EXTM3U\n"); # print the extended header
readFiles($mp3root);

############################################################################
# prints a short Help text
sub help() {
    my $mp3 = $LIST_MP3 ? 'found' : 'NOT found';
    my $ogg = $LIST_OGG ? 'found' : 'NOT found';
    my $fla = $LIST_FLAC ? 'found' : 'NOT found';

print STDERR <<STOP

      Syntax: extm3u.pl <music-dir>

      music-dir This directory will be recursivly searched for audio files

      This tool generates a extended .m3u playlist from a given directory
      for use with XMMS, Winamp (tm) and other music players.
      The playlist is printed to STDOUT. Extended .m3u files contain
      additional informations like length of the song and infos from
      the id3-tag.

      For running this script you'll need the following Perl modules:

      MP3::Info            for .mp3 files   ($mp3)
      Ogg::Vorbis::Header  for .ogg files   ($ogg)
      Audio::FLAC::Header  for .flac files  ($fla)

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
# print a given FLAC
sub printFLAC($$){
    my $file = $_[0];
    my $base = $_[1];
    my $flac = new Audio::FLAC::Header($file);
    my $sec = int($flac->{trackTotalLengthSeconds});
    my $tags = $flac->tags();
    my $artist = $flac->tags('ARTIST');
    my $title = $flac->tags('TITLE');
    my $tracknumber = $flac->tags('TRACKNUMBER');

    if ($artist ne '' || $title ne ''){
        print ("#EXTINF:$sec,$title\n");
    }else{
        print ("#EXTINF:$sec,$base\n");
    }
    print ("$base.flac\n");
}

###############################################################################
# print a given MP3
sub printMP3($$){
    my $file = $_[0];
    my $base = $_[1];
    my $info = MP3::Info::get_mp3info($file);
    my $tag  = MP3::Info::get_mp3tag($file);

    my $sec    = int($info->{SECS});
    my $artist = $tag->{ARTIST};
    my $title  = $tag->{TITLE};

    if ($artist ne '' || $title ne ''){
        print ("#EXTINF:$sec,$artist - $title\n");
    }else{
        print ("#EXTINF:$sec,$base\n");
    }
    print ("$file\n");
}

###############################################################################
# print a given OGG
sub printOGG($$){
    my $file = $_[0];
    my $base = $_[1];
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

    if ($artist ne '' || $title ne ''){
        print ("#EXTINF:$sec,$artist - $title\n");
    }else{
        print ("#EXTINF:$sec,$base\n");
    }
    print ("$file\n");
}

##############################################################################
# Read a given directory and its subdirectories
sub readFiles($) {
    (my $path)=@_;

    opendir(ROOT, $path);
    my @files = readdir(ROOT);
    closedir(ROOT);

    foreach my $file (sort(@files)) {
        next if ($file =~ /^\.|\.\.$/);  #skip upper dirs
        my $fullFilename = "$path/$file";

        if (-d $fullFilename) {
            readFiles($fullFilename); #Recursion
            next;
        }

        if ($LIST_MP3 && $file =~ /^(.*)\.mp3$/i) {
            printMP3($fullFilename,$1); #print MP3-Infos
            next;
        }

        if ($LIST_FLAC && $file =~ /^(.*)\.flac$/i) {
            printFLAC($fullFilename,$1); #print FLAC-Infos
            next;
        }

        if ($LIST_OGG && $file =~ /^(.*)\.ogg$/i) {
            printOGG($fullFilename,$1); #print OGG-Infos
            next;
        }

    }
}




