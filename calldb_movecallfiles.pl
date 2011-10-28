#!/usr/bin/perl

###
### "PhoneBlast" calldb_movefiles.pl
### Philip Rosenberg-Watt, 2011
###


use strict;
use warnings;

my $maxcalls = 5;	# Maximum number of concurrent calls
my $sleeptime = 10;	# Seconds to wait between max. concurrent call checks when maxed out
my $genspacing = 1;	# Seconds between moving outbound call files
my $calldir = "/tmp/callfiles";
my $spooldir = "/var/spool/asterisk/outgoing";
my $lockfile = "/tmp/movecalls.pid";

if (-f $lockfile) {
	exit;
}
system ("echo $$ > $lockfile");
&movefiles($maxcalls);
system("rm $lockfile");
exit;

### Move files to spool directory with a maximum of $ concurrent calls
sub movefiles ($) {
	my $limitcalls = $_[0];
	while (int(`ls $calldir | wc -l`)) {
		my $spoolcount = int(`ls $spooldir | wc -l`);
		if ($spoolcount < $limitcalls) {
			my $nextfile = `ls -t $calldir/ | tail -1`;
			chomp($nextfile);
			system("mv $calldir/$nextfile $spooldir/");
			sleep $genspacing;
		} else {
			sleep $sleeptime;
		}
	}
	return;
}

exit;
