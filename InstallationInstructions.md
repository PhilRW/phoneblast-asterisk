# Introduction #

Simple:
  * Install the .pl files in /var/lib/asterisk/agi-bin/
  * Install the .sh file in /var/lib/asterisk/sounds/calldb/
  * Add the extensions.conf context to your dialplan
  * Redirect an incoming DID to that context.

## Prerequisites ##

  * Asterisk (1.8+ recommended)
  * Perl
  * Asterisk::AGI for Perl
  * [Cepstral](http://cepstral.com) text-to-speech (or modify genwavs.sh accordingly)

# Details #

See [my blog](http://blog.rosenberg-watt.com/2011/04/12/phoneblast-for-asterisk-because-sharing-is-caring/) for more information.