#!/usr/bin/perl

###
### "PhoneBlast" calldb.pl
### Philip Rosenberg-Watt, 2011
###


use strict;
use warnings;
use Asterisk::AGI;
use File::Copy;

### Configure initial call delay and additional calls afterwards:
my $delay = 20;			# How long to wait before placing first outbound call
my $callspacing = 1;		# Seconds betwen calls. (Now handled by $movecallfilescmd, but kept to keep order of files)
my $callbackdelay = 60;		# How long to wait vefore calling back user to verify PIN w/ double opt-in method

my $agi = new Asterisk::AGI;
my %input = $agi->ReadParse();
my $spool_dir = "/var/spool/asterisk/outgoing";
my $wav_dir = "/var/lib/asterisk/sounds/calldb/cache";
my $movecallfilescmd = "/var/lib/asterisk/agi-bin/calldb_movecallfiles.pl";
my $swiftcmd = "/usr/local/bin/swift";		# Make sure this exists; script does not check for this
my $tmp_dir = "/tmp/callfiles";			# Temporary directory to store call files before they're placed
my $maxretries = 3;				# Maximum times to retry an outbound call
my $retrytime = 60;				# How long to wait between retries
my $waittime = 45;				# How long to wait for someone to answer phone before hanging up
my $chan = "Local";
my $dbname = $agi->get_variable("DBNAME");
my $dbdid = $agi->get_variable("DBDID");
my $dbdesc = $agi->get_variable("DBDESC");
my $cid = $input{callerid};
my $pin = $agi->get_variable("PIN");
if ($pin) {		# CID will be empty if it is a PIN verification callback, therefore set $cid to retrieved variable
	$cid = $agi->get_variable("CALLEDCID");
}
my $callerid = "\"PhoneBlast\" <$cid>";
my $dbfile = "/var/lib/asterisk/agi-bin/phonenum-db-".$dbname.".txt";
my $outfile = $wav_dir."/".$dbname."_".$cid."_outgoing";
my $tmp_outfile = "/tmp/".$dbname."_".$cid."_outgoing";
my $namefile = $wav_dir."/".$dbname."_".$cid."_name";
my $tmp_namefile = "/tmp/".$dbname."_".$cid."_name";
my $dbdescfile = $wav_dir."/".$dbname."_name";
my @db;
my %dbh;
my $count;
my $input = 0;
my $breakloop = 1;

### Create temporary dir if it doesn't exist
unless (-d $tmp_dir) {
	system("mkdir $tmp_dir");
	$agi->verbose("$tmp_dir does not exist, creating directory.");
}

### Create calldb cache dir if it doesn't exist
unless (-d $wav_dir) {
	system("mkdir $wav_dir");
	$agi->verbose("$wav_dir does not exist, creating directory.");
}

### Create group name description file if it doesn't already exist
unless (-f $dbdescfile.".wav") {
	system("$swiftcmd \"$dbdesc\" -o $dbdescfile.wav");
	$agi->verbose("$dbdescfile does not exist, creating file.");
}

&cidcheck();

### If PIN is defined we know this is a PIN verification callback
if ($pin) {
	$agi->answer();
	$agi->stream_file("silence/2");
	$agi->stream_file("hello");
	ENTERPASSWORD:
	$agi->exec("Read","READPIN,calldb/please-enter-your-temporary-verification-password-now,4");
	my $readpin = $agi->get_variable("READPIN");
	### Add CID to DB if PIN is correct.
	if ($readpin == $pin) {
		&dbread();
		push(@db, $cid);
		&dbsave();
		$agi->stream_file('silence/1');
		$agi->stream_file('auth-thankyou');
		$agi->stream_file('silence/1');
		$agi->say_digits("$cid");
		$agi->stream_file('num-was-successfully');
		$agi->stream_file('added');
		$agi->stream_file('silence/1');
		&recname();
	} else {
		$agi->stream_file('silence/1');
		$agi->stream_file('vm-incorrect');
		&loopcheck();
		$agi->stream_file('silence/1');
		$agi->stream_file('wrong-try-again-smarty');
		goto ENTERPASSWORD;
	}
}

&dbread();

### If caller is not on list, ask if caller wants to join.
if (not exists $dbh{$cid}) {
	while (!$input) {
		&saywelcome();
		if (!$input) { $agi->stream_file('calldb/not-on-list-would-you-like-to-join'); }
		if (!$input) { $input = $agi->stream_file('1-yes-2-no', '12'); }
		if (!$input) { $input = $agi->stream_file('silence/6', '12'); }
		if (!$input) { &loopcheck(); }
	}
	$input = $input - 48;
	### Give callback instructions and speak the PIN twice, then generate callback and hangup
	if ($input == 1 ) {
		$pin = &genpin(4);
		$agi->stream_file("silence/1");
		$agi->stream_file("privacy-your-callerid-is");
		$agi->say_digits("$cid");
		$agi->stream_file("calldb/pin-callback-instructions");
		$agi->say_digits("$pin");
		&gencallback();
		$agi->stream_file("silence/4");
		$agi->say_digits("$pin");
		$agi->stream_file("silence/4");
		$agi->say_digits("$pin");
		&saygoodbye();
	} elsif ($input == 2) {
		&saygoodbye();
	}	
}

&saywelcome();
### The main menu of the system
MAINMENU:
### If for some reason the caller is missing a recorded name (e.g. CID was added to DB file manually), prompt caller to record name
unless (-f $namefile.".wav") {
	&recname();
}
$agi->stream_file('main-menu');
$agi->stream_file('silence/1');
$input = 0;
$breakloop = 1;
### Loop main menu options with a loop check.
while (!$input) {
	if(!$input) { $input = $agi->stream_file('to-compose-a-message', '12345'); }
	if(!$input) { $input = $agi->stream_file('press-1', '12345'); }
	if(!$input) { $input = $agi->stream_file('calldb/to-remove-yr-tn-from-list', '12345'); }
	if(!$input) { $input = $agi->stream_file('press-2', '12345'); }
	if(!$input) { $input = $agi->stream_file('calldb/to-rerecord-yr-name', '12345'); }
	if(!$input) { $input = $agi->stream_file('press-3', '12345'); }
	if(!$input) { $input = $agi->stream_file('to-hang-up', '12345'); }
	if(!$input) { $input = $agi->stream_file('press-4', '12345'); }
	if(!$input) { $input = $agi->stream_file('silence/6', '12345'); }
	if(!$input) { &loopcheck(); }
}

$input = $input - 48;

### Caller wants to record and broadcast an outbound message
if ($input == 1) {
	&dbread();
	### Warn if phone list is empty
	if ($count == 0) {
		$agi->stream_file("silence/1");
		$agi->stream_file("beeperr");
		$agi->stream_file("beeperr");
		$agi->stream_file("warning");
		$agi->stream_file("calldb/nobody-else-on-call-list");
		$agi->stream_file("nobody-but-chickens");
		$agi->stream_file("please-try-again-later");
	### Record the outgoing message
	} else {
		RECORD:
		$agi->stream_file('silence/1');
		$agi->stream_file('vm-rec-temp');
		$agi->stream_file('beep');
		$agi->record_file("$tmp_outfile","wav","#","-1",,"1","s=10");
		$agi->stream_file('silence/1');
		PLAYBACK:
		$agi->stream_file("$tmp_outfile");
		$input = 0;
		$breakloop = 1;
		### Press 1 to accept, 2 to listen, 3 to re-record
		while (!$input) {
			if (!$input) { $input = $agi->stream_file('vm-review', '123'); }
			if (!$input) { $input = $agi->stream_file('silence/6', '123'); }
			if (!$input) { &loopcheck(); }
		}
		$input = $input - 48;
		### Count number of outbound calls, generate calls, and hangup
		if ($input == 1) {
			move("$tmp_outfile".".wav","$outfile".".wav");
			&gencalls();
			$agi->stream_file('silence/1');
			$agi->stream_file("vm-msgsaved");
			$agi->stream_file("the-num-i-have-is");
			$agi->say_number("$count");
			$agi->stream_file("outbound");
			if ($count == 1) {
				$agi->stream_file("call");
			} else {
				$agi->stream_file("calls");
			}
			$agi->stream_file("calldb/sending-now");
			$agi->stream_file("auth-thankyou");
		} elsif ($input == 2) {
			goto PLAYBACK;
		} elsif ($input == 3) {
			goto RECORD;
		}
	}
### Remove caller from list
} elsif ($input == 2) {
	&dbread();
	@db = grep { $_ != $cid } @db;
	&dbsave();
	$agi->stream_file('silence/1');
	$agi->say_digits("$cid");
	$agi->stream_file('num-was-successfully');
	$agi->stream_file('removed');
	$agi->stream_file('silence/1');
### Re-record caller name
} elsif ($input == 3) {
	&recname();
	goto MAINMENU;
### Graceful hangup
} elsif ($input == 4) {
	&saygoodbye();
} elsif ($input == 5) {
	&dbread();
	$count += 1;
	$agi->stream_file("silence/1");
	$agi->stream_file("the-num-i-have-is");
	$agi->say_number("$count");
	if ($count == 1) {
		$agi->stream_file("user");
	} else {
		$agi->stream_file("users");
	}
	$agi->stream_file("vm-star-cancel");
	$input = 0;
	my $spoken = 0;
	foreach my $phonenum (@db) {
		my $namefile = $wav_dir."/".$dbname."_".$phonenum."_name";
		if (-f $namefile.".wav") {
			if (!$input) { $input = $agi->stream_file("$namefile", '*'); }
			$spoken++;
		}
	}
	if ($spoken != $count && !$input) {
		$agi->stream_file("and");
		my $unspoken = $count - $spoken;
		$agi->say_number("$unspoken");
		if ($unspoken == 1) {
			$agi->stream_file("user");
		} else {
			$agi->stream_file("users");
		}
		$agi->stream_file("calldb/with-no-recorded-name");
	}
	$agi->stream_file("silence/1");
	goto MAINMENU;
}
&saygoodbye();


###### Subroutines


### Read DB file into memory
sub dbread {
	unless (-f $dbfile) {
		system("touch $dbfile");
		$agi->verbose("$dbfile does not exist, creating file.");
	}
	open(DB, $dbfile) || $agi->verbose('ERROR: Could not open file!');
	@db=<DB>;
	close(DB);
	chomp(@db);
	@dbh{@db}=();
	$count = @db - 1;
}


### Save DB to file
sub dbsave {
	use Fcntl qw(:flock :seek);
	open(DB,">$dbfile") || die("Could not open file!");
	flock(DB, LOCK_EX);
	seek(DB, 0, SEEK_SET);
	foreach my $phonenum (@db) {
		print DB "$phonenum\n";
	}
	close(DB);
}


### Greet caller with his recorded name (if available) and list name
sub saywelcome {
	$agi->stream_file('silence/1');
	$agi->stream_file('welcome');
	if (-f $namefile.".wav") {
		$agi->stream_file("$namefile");
	}
	$agi->stream_file("calldb/this-is-the-phoneblast-list");
	$agi->stream_file("$dbdescfile");
	$agi->stream_file('calldb/welcome');
	$agi->stream_file('silence/1');
}


### Say goodbye and hangup
sub saygoodbye {
	$agi->stream_file('silence/1');
	$agi->stream_file('goodbye');
	$agi->stream_file('silence/1');
	$agi->hangup();
	exit(0);
}


### Disconnect after a loop of 3
sub loopcheck {
	$breakloop++;
	if ($breakloop > 3) {
		$agi->stream_file("beeperr");
		$agi->stream_file("connection-timed-out");
		&saygoodbye();
	}
}


### Check if CallerID is valid
sub cidcheck ($) {
	if ($cid =~ m/[2-9]{1}[0-9]{2}[2-9]{1}[0-9]{6}/) {
		return;
	} else {
		$agi->stream_file('silence/1');
		$agi->stream_file('beeperr');
		$agi->stream_file('beeperr');
		$agi->stream_file('beeperr');
		$agi->stream_file('warning');
		$agi->stream_file('calldb/not-10-digits-or-callerid-blocked');
		$agi->stream_file("please-try-again-later");
		&saygoodbye();
	}
}


### Record caller's name
sub recname {
	my $newrecording = 0;
	if (-f $namefile.".wav") {
		$agi->stream_file("silence/1");
		$agi->stream_file("calldb/your-recorded-name-is");
		$agi->stream_file("$namefile");
	} else {
		RECORD:
		$agi->stream_file('silence/1');
		$agi->stream_file('vm-rec-name');
		$agi->stream_file('beep');
		$agi->record_file("$tmp_namefile","wav","#","-1",,"1","s=3");
		$newrecording = 1;
		$agi->stream_file('silence/1');
		$agi->stream_file("$tmp_namefile");
	}
	SUBMENU:
	$input = 0;
	$breakloop = 1;
	while (!$input) {
		if (!$input) { $input = $agi->stream_file('to-accept-recording', '123'); }
		if (!$input) { $input = $agi->stream_file('press-1', '123'); }
		if (!$input) { $input = $agi->stream_file('to-listen-to-it', '123'); }
		if (!$input) { $input = $agi->stream_file('press-2', '123'); }
		if (!$input) { $input = $agi->stream_file('to-rerecord-it', '123'); }
		if (!$input) { $input = $agi->stream_file('press-3', '123'); }
		if (!$input) { $input = $agi->stream_file('silence/6', '123'); }
		if (!$input) { &loopcheck(); }
	}
	$input = $input - 48;
	if ($input == 1) {
		if ($newrecording) {
			system("mv $tmp_namefile.wav $namefile.wav");
		}
		$agi->stream_file('silence/1');
		$agi->stream_file('auth-thankyou');
		$agi->stream_file('silence/1');
		return;
	} elsif ($input == 2) {
		$agi->stream_file('silence/1');
		if ($newrecording) {
			$agi->stream_file("$tmp_namefile");
		} else {
			$agi->stream_file("$namefile");
		}
		goto SUBMENU;
	} elsif ($input == 3) {
		goto RECORD;
	}
	return;
}


### Generate the outbound calls
sub gencalls {
	&dbread();
	my $initialdelay = $delay;
	@db = grep { $_ != $cid } @db;
	foreach my $phonenum (@db) {
		my $randomnumber = &genpin(32);
		my $tmp_filename = sprintf("%s/%s-%s-%s-%s.call", $tmp_dir, $dbname, $phonenum, $cid, $randomnumber);
		open(CALLFILE, ">$tmp_filename");
		printf CALLFILE q{#
Channel: %s/%s@from-internal

MaxRetries: %s
RetryTime: %s
WaitTime: %s
CallerID: %s

SetVar: PLAYFILE=%s
SetVar: NAMEFILE=%s
SetVar: DBNAME=%s
SetVar: DBFILE=%s
SetVar: DBDESCFILE=%s
SetVar: KEEPCID=TRUE
Application: AGI
Data: calldb_announce.pl
}, $chan, $phonenum, $maxretries, $retrytime, $waittime, $callerid, $outfile, $namefile, $dbname, $dbfile, $dbdescfile;
		close(CALLFILE);
		system ("touch -d \"$delay seconds\" $tmp_filename");
		$delay = $delay + $callspacing;
	}
	&bgmovefiles();
	return;
}


### Generate a random PIN
sub genpin ($) {
	$pin = "";
	my @pinchars=('1'..'9');
	foreach (1..$_[0]) {
		$pin.=$pinchars[rand @pinchars];
	}
	return $pin;
}


### Generate PIN verification callback
sub gencallback {
	$callerid = "\"PhoneBlast\" <$dbdid>";
	my $tmp_filename = sprintf("%s/%s-%s-callback.call", $tmp_dir, $dbname, $cid);
	open(CALLFILE, ">$tmp_filename");
	printf CALLFILE q{#
Channel: %s/%s@from-internal

MaxRetries: 0
CallerID: %s

SetVar: PIN=%s
SetVar: DBNAME=%s
SetVar: DBDID=%s
SetVar: KEEPCID=TRUE
SetVar: CALLEDCID=%s
Application: AGI
Data: calldb.pl
}, $chan, $cid, $callerid, $pin, $dbname, $dbdid, $cid;
	close(CALLFILE);
	system ("touch -d \"$callbackdelay seconds\" $tmp_filename");
	&bgmovefiles();
	return;
}


## Background process to move files
sub bgmovefiles() {
	my $pid = fork;
	die "Fork failed: $!" unless defined $pid;
	unless ($pid) {
		use Proc::Daemon;
		Proc::Daemon::Init();
		system("$movecallfilescmd");
		die "Exec failed: $!\n";
		exit(0);
	}
}


exit(0);
