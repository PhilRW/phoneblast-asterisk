#!/bin/sh

cd /var/lib/asterisk/sounds/custom/calldb/

swift "Hi. <break strength='medium' /> Please hold a moment for an important message." -o please-hold-a-moment-for-an-important-message.wav

swift "with no recorded name." -o with-no-recorded-name.wav

swift "Your recorded name is:" -o your-recorded-name-is.wav

swift "Incoming message for the PhoneBlast list:" -o incoming-message-for-the-phoneblast-list.wav

swift "This is the PhoneBlast list:" -o this-is-the-phoneblast-list.wav

swift "Provided by Philip Rosenberg-Watt <break strength='x-weak' /> and NeoVisic Productions Inc." -o welcome.wav

swift "Sending now." -o sending-now.wav

swift "Please enter your temporary verification password now." -o please-enter-your-temporary-verification-password-now.wav

swift "To remove your telephone number from the list" -o to-remove-yr-tn-from-list.wav

swift "To re-record your name" -o to-rerecord-yr-name.wav

swift "No outbound calls will be placed, because yours is the only number on the list." -o nobody-else-on-call-list.wav

swift "Either there is a problem with your telephone number, or your caller ID has been blocked." -o not-10-digits-or-callerid-blocked.wav

swift "This telephone number is not on the list. Would you like to join the list?" -o  not-on-list-would-you-like-to-join.wav

swift "If your caller ID is not correct, please hang up now <break strength='x-weak' /> and call back from the correct number. <break time='2s' /> The system will now generate a random temporary password and call you back after one minute. You will need to enter the password correctly in order to join the list. The system will not try to call you again if you don't answer the first call, so please answer your phone. Your temporary password will only be used for this one callback in order to verify your phone number. If you do not receive a call within fifteen minutes, please call back and try again. Listen carefully and remember your password. Your random password is:" -o pin-callback-instructions.wav
