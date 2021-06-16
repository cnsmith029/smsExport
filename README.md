# smsExport
smsExport reads your iOS device backup files and creates a CSV file of text messages.  It uses the messages sql database and matches up phone numbers with the addressbook database from the iOS device.  Output is a CSV file with a line by line representation of text messages.

REQUIREMENTS:

1) Perl 5 interpreter. <BR>
https://www.perl.org/get.html

2) sqlite3 executable. <BR>
https://www.sqlite.org/download.html

3) A local unencrypted iOS device backup.  
Backups can be made with iTunes or Finder on a Mac, and iTunes in Windows.<BR>
https://www.apple.com/itunes <BR>
https://www.apple.com/itunes/download/win32 <BR>
https://www.apple.com/itunes/download/win64 <BR>

4) Permission to access your MobileSync/Backup directory. On macOS you may need to give Terminal full disk access (under Security and Privacy) to run this script.  You can revoke this permission after you run smsExport.

Simply run the run the smsExport-x.x.x.pl script on the command line, and it will prompt for iOS backup location if you do not want to use the defaults.
 
smsExport will copy the files it needs to access from your MobileSync/Backup directory to a new folder on your Desktop named sms/Exports/UID/date/copiedMsyncBackupFiles.  It will also create some extra files in UID/date/tableData folder.  The main file you came here for is called (deviceName)-smsWithToFrom.csv found under UID/date.
  

