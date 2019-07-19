#!/usr/bin/perl

###
### "PhoneBlast" calldb_announce.pl
### Philip Rosenberg-Watt, 2011
###

use strict;
use warnings;
use Asterisk::AGI;

my $agi = new Asterisk::AGI;
my %input = $agi->ReadParse();
my $playfile = $agi->get_variable("PLAYFILE");
my $namefile = $agi->get_variable("NAMEFILE");
my $dbname = $agi->get_variable("DBNAME");
my $dbfile = $agi->get_variable("DBFILE");
my $dbdescfile = $agi->get_variable("DBDESCFILE");
my $dbconf = $agi->get_variable("DBCONF");
my $input = 0;
my $breakloop = 1;
my $played = 0;

$agi->answer();
$agi->stream_file("silence/2");
### "Hi. Please hold a moment for an important reminder."
#$agi->stream_file("custom/reminder5");
$agi->stream_file("calldb/please-hold-a-moment-for-an-important-message");
$agi->exec("WaitForSilence", "2000");
### Loop message a few times in case voicemail actually picked up
while (!$input) {
	RESTART:
	&playmessage();
	if ($breakloop >= 2) {
		&saygoodbye();
	}
	if (!$input) { $input = $agi->stream_file("to-hear-msg-again", "123"); }
	if (!$input) { $input = $agi->stream_file("press-1", "123"); }
	if (!$input) { $input = $agi->stream_file("custom/calldb/to-transfer-to-conference", "123"); }
	if (!$input) { $input = $agi->stream_file("press-2", "123"); }
	if (!$input) { $input = $agi->stream_file("otherwise-press", "123"); }
	if (!$input) { $input = $agi->stream_file("digits/3", "123"); }
	if (!$input) { $input = $agi->stream_file("silence/2", "123"); }
	if (!$input) { $input = $agi->stream_file("restarting", "123"); }
	if (!$input) { $input = $agi->stream_file("silence/1", "123"); }
	$breakloop++;
}
$input -= 48;
### Callee requested repeat
if ($input == 1) {
	$agi->stream_file("silence/1");
	$agi->stream_file("restarting");
	$agi->stream_file("silence/1");
	$input = 0;
	$breakloop = 1;
	goto RESTART;
### Transfer to conference
} elsif ($input == 2) {
	$agi->stream_file("silence/1");
	$agi->stream_file("custom/calldb/you-are-now-being-transferred-to-conference");
	$agi->stream_file("silence/1");
	$agi->exec("ConfBridge",$dbconf);
	$agi->hangup();
### Graceful disconnect
} elsif ($input == 3) {
	&saygoodbye();
}
	
&saygoodbye();

sub saygoodbye {
	$agi->stream_file("silence/1");
	$agi->stream_file("goodbye");
	$agi->stream_file("silence/1");
	$agi->hangup();
	exit;
}

sub playmessage {
	my @messages = (	"custom/calldb/incoming-message-for-the-phoneblast-list",
				"$dbdescfile",
				"message-from",
				"$namefile",
				"$playfile",
				"silence/1" );
	if (!$played) {
		for my $message (@messages) {
			$agi->stream_file("$message");
		}
		$played = 1;
	} else {
		for my $message (@messages) {
			if (!$input) { $input = $agi->stream_file("$message", "12"); }
		}
	}
	return;
}

exit;
