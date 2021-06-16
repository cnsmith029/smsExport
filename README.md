# smsExport
smsExport creates a CSV file of text messages from an iOS device.  The CSV file can be opened in Excel or other spreadsheet program.

smsExport works by reading iOS device backup files, specifically the sms.db and AddressBook.sqlitedb database backups.  Using the sms.db and AddressBook.sqlitedb, smsExport will match up phone numbers and email addresses to the entries listed in Contacts at the time of the iOS Backup.  The result will be a nice line by line representation of your text messages displayed using From, To,	subject, text.

smsExport will NOT read encrypted iOS backups.  You will need to make an unencrypted local backup of your iOS device for smsExport to work.

WARNING: There is a LOT of personal and security sensitive information contained within iOS backups.  Apple recomends encrypting these iOS backups for your own security.  Unless you are operating in a secure environment, i.e. your computer does not have any network hardware, you may decide to keep these backups encrypted. Alternatively you could do a one time unencrypted backup, run smsExport, then delete the unencrypted iOS backup.

REQUIREMENTS:

Microsoft Windows Requirements:

Before you can run smsExport on Microsoft Windows, you will need to install 2 programs and then create a local unencrypted backup of your iOS Devices.  Comply with the 4 items listed below.

1) Perl 5 interpreter. <BR>
https://www.perl.org/get.html <BR>
https://strawberryperl.com

2) sqlite3 executable. <BR>
https://www.sqlite.org/download.html

3) A local unencrypted iOS device backup. iOS device backups are made with iTunes. <BR>
https://www.apple.com/itunes <BR>
https://www.apple.com/itunes/download/win32 <BR>
https://www.apple.com/itunes/download/win64 <BR>

4) Permission to access your MobileSync/Backup directory. 


macOS REQUIREMENTS:

1) A local unencrypted iOS device backup.  iOS backups can be made with iTunes or Finder on a Mac. <BR>

2) Permission to access your MobileSync/Backup directory. On macOS you may need to give Terminal full disk access (under Security and Privacy) to run this script.  You can revoke this permission after you run smsExport.
  

USAGE:
 
Simply run the run the smsExport-1.1.1.pl script on the command line with "perl smsExport-1.1.1" , and it will prompt for iOS backup location if you do not want to use the defaults.
 
smsExport will copy the files it needs to access from your MobileSync/Backup directory to a new folder on your Desktop named sms/Exports/UID/date/copiedMsyncBackupFiles.  It will also create some extra files in UID/date/tableData folder.  The main file you came here for is called (deviceName)-smsWithToFrom.csv found under Desktop/smsExports/UID/date/.
  

