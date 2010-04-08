#!/usr/bin/perl

use MP3::Info; $LIST_MP3 = 1;           # MP3 support - comment out if not needed
use Ogg::Vorbis::Header; $LIST_OGG = 1; # OGG Vorbis Support - comment out if not needed

# Function prototypes:
sub readFiles($);
sub printMP3($$);
sub printOGG($$);
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
print STDERR <<STOP

      Syntax: extm3u.pl <mp3-dir>

      mp3-dir   This directory will be recursivly searched for mp3s

      This tool generates a extended .m3u playlist for use with XMMS,
      Winamp (tm) and other MPEG layer 3 players from a given directory.
      The playlist is printed to STDOUT. Extended .m3u files contain
      additional informations like length of the song and Infos from
      the id3-tag.

      For running this script you'll need the MP3::Info and/or 
      Ogg::Vorbis::Header perl-modules.
      Get them from CPAN or install the appropriate package of your
      distribution.
      
      _____________________________________________________________________
      extm3u.pl - Generates an extended .m3u mp3-Playlist
      Copyright (C) 2004 Andreas Gohr <andi\@splitbrain.org>

      This program is free software; you can redistribute it and/or
      modify it under the terms of the GNU General Public License as
      published by the Free Software Foundation; either version 2 of
      the License, or (at your option) any later version.
      
      See COPYING for details
STOP
}


###############################################################################
# print a given MP3
sub printMP3($$){
	my $file = $_[0];
        my $base = $_[1];
	my $info = get_mp3info($file);
	my $tag = get_mp3tag($file);

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
# print a given MP3
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

    if ($LIST_OGG && $file =~ /^(.*)\.ogg$/i) {
      printOGG($fullFilename,$1); #print OGG-Infos
      next;
    }

  }
}



