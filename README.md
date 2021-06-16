# smsExport
smsExport reads your iOS device backup files and creates a CSV file of text messages.  It uses the messages sql database and matches up phone numbers with the addressbook database from the iOS device.  Output is a CSV file with a line by line representation of text messages.

REQUIREMENTS:

1) Perl 5 interpreter.<BR>
https://www.perl.org/get.html

2) sqlite3 executable.
https://www.sqlite.org/download.html

3) A local unencrypted iOS device backup.  
Backups can be made with iTunes or Finder on a Mac, and iTunes in Windows.
https://www.apple.com/itunes
https://www.apple.com/itunes/download/win32
https://www.apple.com/itunes/download/win64


