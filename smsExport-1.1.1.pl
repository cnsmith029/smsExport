#!/usr/bin/perl

use warnings;
use strict;

use File::Copy;


## Requirements
## 1) unencrypted iOS backup
## 2) sqlite3 installed at c:\sqlite3\sqlite3.exe
## 3) Perl 5 ish



my $thisScript = "smsExport-1.1.1.pl";

## Version 1 should work with iOS Version 11 through 14  
## 	iOS V 11 - Confirmed
## 	iOS V 13.3.1 - Confirmed
##	iOS V 14.4.2 - Confirmed
##	iOS v 14.6 - Confirmed

## Version 1.1.1 added support for Windows iTunes backups.


###############################################################################
#### Global variables
##
#

### Set flags for OS version, win or mac.

my $macOS;


if ($^O =~ /darwin/i) {
	$macOS = 1;
}
### Define msyncBackups which is the directory where the collection of iOS
### backups are located.

my $msyncBackups; 

## macOS Location
if ($macOS) {
	$msyncBackups= "$ENV{'HOME'}/Users/rosyraspberry/iCloud Drive/Backup/Backup 32adf104d5d9f1679779490c6e6791580dffe540";
}
### Define smsExportsDirectory.  This is where we will copy DB files and output the files we generate.
my $smsExportsDirectory ;

## macOS smsExportsDirectory
if ($macOS) {
	$smsExportsDirectory = "$ENV{'HOME'}/Desktop/smsExports";
}

## Make sure we have the info we need to continue.
unless ($msyncBackups && $smsExportsDirectory) { die "ERROR: either \$msyncBackups or \$smsExportsDirectory is undefined."; }


### Database file names
my $sms_db_FILENAME =  "3d0d7e5fb2ce288813306e4d4636395e047a3d28"; ## sms.db  sqlite DB where messages stored. Name of backup file in MobileSync/Backups
my $AddressBook_sqlitedb_FILENAME = "31bb7ba8914766d4ba40d6dfb6113c8b614be442"; ## AddressBook.sqlitedb   sqlite DB where AddressBook.sqlitedb aka Contacts stored.  Name of backup file in MobileSync/Backups


### clear command
my $clearCommand = "clear";

## sqlite3 command
my $sqlite3 = "/usr/bin/sqlite3";


#system $clearCommand;
print "
 -----------------------------------------------------------------------------
| Running $thisScript at " . localtime . "
|
| Will read iOS backup files, then attempt to export all messages in the SMS 
| database into one CSV file.  This could be a big file if you are popular.
| 
| Note that only message text is exported.  Pictures and other attachments
| including multimedia are NOT exported.
|
| Files will be written to: $smsExportsDirectory
 -----------------------------------------------------------------------------\n\n\n";



#### Setup output directories.

my $userInputDirectory;
 
if ($ARGV[0] && $ARGV[0] ne "-v" ) {
	$userInputDirectory = $ARGV[0];
	#$userInputDirectory =~ s/\\ //g;  ## Remove space escape.  Let only be space. (no longer need this)

	if ($userInputDirectory =~ m/\*/) {
		print "Sorry, wildcards not allowed when specifying directories.  Exiting.\n";
		exit;
	}

	if ($userInputDirectory) {
		if (-d $userInputDirectory) {
			$msyncBackups = $userInputDirectory;
		} else {
			print "Directory [$userInputDirectory] does not exist.  Exiting.\n";
			exit;
		}
	}
}


#### Ask user if default MobileSync Backup folder is ok, or do they want to specify.

print "Will use MobileSync Backup folder at:\n[$msyncBackups]\n\n";
print "Press return to continue.  q <return> to quit.  Or specify full path to the folder of backup UIDs you want to use.\n";
my $userInputMobileSyncBackup = <STDIN>;
chomp $userInputMobileSyncBackup;

## If user typed q or Q (return) then exit.
if ($userInputMobileSyncBackup eq "q" || $userInputMobileSyncBackup eq "Q") {
	print "Done.  No files were copied or created.\n";
	exit;
} 

## If user typed anything else then use it for $msyncBackups;
if ($userInputMobileSyncBackup =~ m/.+/) {
	## user said something, re assign it ti $msyncBackups
	$userInputMobileSyncBackup =~ s/\\ / /g;  ## Remove space escape.  Let only be space.
	$userInputMobileSyncBackup =~ s/ $//;  ## Remove trailing space (happens if user drags item from finder)

	$msyncBackups = $userInputMobileSyncBackup;
}



#### Get hash of files in msyncBackups directory thought to be iOS backup directories.

## Read all files in msyncBackups directory and add to msyncBackupDirListing array.
unless (-d $msyncBackups) { print "Directory does not exist [$msyncBackups]."; exit; }
opendir(DIRH, "$msyncBackups") or die "\n\nERROR: Can't open [$msyncBackups]. $!";
my @msyncBackupDirListing = readdir DIRH;

close DIRH;

## Get new hash of directories in msyncBackups thought to be iOS backup directories.  Key is file name, value is mtime of Info.plist.
my %msyncBackupFiles; 
my $plistWasFound = 0;

foreach (@msyncBackupDirListing) {

	next if /^\./; ## Ignore files that begin with a '.'
	next unless (-d "$msyncBackups/$_"); ## Ignore files that are not a directory.
	next unless (-r "$msyncBackups/$_\/Info.plist"); ## Ignore directories that do not contain a readable Info.plist file.
	$plistWasFound = 1;
	$msyncBackupFiles{$_} = 1;
	my @stat = stat ("$msyncBackups/$_/Info.plist");
	unless ($stat[9]) { warn "WARNING: Could not get mtime for $msyncBackups/$_/Info.plist"; next; }
	$msyncBackupFiles{$_} = $stat[9];

}

## Sort the msyncBackupFiles hash by values.
my @keys_msyncBackupFiles = sort { $msyncBackupFiles{$a} <=> $msyncBackupFiles{$b} } keys(%msyncBackupFiles);
my @vals_msyncBackupFiles = @msyncBackupFiles{@keys_msyncBackupFiles};

## Check to see at least one Info.plist was found.  If not then ERROR out.
unless ($plistWasFound ) { die "\nERROR: no Info.plist(s) were found OR or are readable.  Looked in [$msyncBackups/*/Info.plist]\n"; }


## Get the most recent backup UID folder to present to user.
my $mostRecentBackupUID =  $keys_msyncBackupFiles[$#keys_msyncBackupFiles];


## Verify user selection.  Repeat until valid selection or quit is received.
my $chosenBackupSelection;
my $chosenBackupUID;
{
	#system ($clearCommand);
	presentBackups();

	print "Press return to use the most recent backup OR choose from the above list.\nEnter (1 to " . scalar @keys_msyncBackupFiles . ") or q to quit. " ;
	$chosenBackupSelection = <STDIN>;
	chomp $chosenBackupSelection;


	## If user entered q or quit then quit.
	$chosenBackupSelection = lc $chosenBackupSelection;
	if ($chosenBackupSelection eq "q" || $chosenBackupSelection eq "quit") {
		print "Exiting.\n";
		exit;
	}


	## If user pressed return without typing anything else, then assume wants mostRecentBackupUID
	if ($chosenBackupSelection eq "") {
		$chosenBackupSelection = scalar@vals_msyncBackupFiles;
		$chosenBackupUID = $keys_msyncBackupFiles[$#vals_msyncBackupFiles];
	} else {

		## if user entered a number from list then set chosenBackupUID accordingly.
		if ($chosenBackupSelection =~ m/\D/ || $chosenBackupSelection < 1 || $chosenBackupSelection > scalar@vals_msyncBackupFiles) {
			#system ($clearCommand);
			print "Invalid selection. Only numbers 1 to ". scalar @keys_msyncBackupFiles . " are allowed.\n\n";
			sleep 2;
			redo;
		}

		$chosenBackupUID = $keys_msyncBackupFiles[$chosenBackupSelection-1];
	}
}


print "Processing item number: $chosenBackupSelection [$msyncBackups/$chosenBackupUID]\n";


## Verify that chosenbackupUID exists, otherwise ERROR out.
unless (-e "$msyncBackups/$chosenBackupUID") { die "\n\n\nERROR: $msyncBackups/" . quotemeta($chosenBackupUID) . " does not exist.\n" }


#### Make sure smsExportsDirectory exists, otherwise create it.
unless (-d "$smsExportsDirectory") {
	mkdir ($smsExportsDirectory) == 1 or die "\nERROR: Could not create [$smsExportsDirectory]. $!";
}


#### Make sure smsExportsDirectory is writeable.
unless (-d "$smsExportsDirectory" && -w "$smsExportsDirectory") {
	die "$! \n\nERROR: output directory [$smsExportsDirectory] does not exist OR is not writeable.\n";
}



#### Create subdirectory for output in smsExportsDirectory. In the form
#### /Users/mark/smsHistory/UID/timestamp

## Define outputDirectory and make sure does not already exist.
my $outputDirectory = "$smsExportsDirectory/$chosenBackupUID";
unless (-d "$outputDirectory") {
	mkdir ($outputDirectory) == 1 or die "\nERROR: Could not create [$outputDirectory]. $!";
}

## Add timestamp directory to output directory.
my $smsExportRanAt = returnTimestamp(time);
$outputDirectory = "$smsExportsDirectory/$chosenBackupUID/$smsExportRanAt";
if (-d "$outputDirectory") {
	die "\nERROR: Directory already exists, cannot create [$outputDirectory]. $!";
}
mkdir ($outputDirectory) == 1 or die "\nERROR: Could not create [$outputDirectory]. $!";



#### Copy database files from MobileSync/Backup directory into outputDirectory.

## Create subfolder in outputDirectory for copied files from MobileSync/backup

unless (-d "$outputDirectory/copiedMsyncBackupFiles") {
	mkdir ("$outputDirectory/copiedMsyncBackupFiles") == 1 or die "$! \n\nERROR: Could not create [$outputDirectory/copiedMsyncBackupFiles].\n";
}

## Older iOS would keep all backup files in the root backup folder.  Later divided up with subdirectories named with first 2 characters of backup file.

## Copy assuming all the same directory (Earlier versions of iOS)
if (-e "$msyncBackups/$chosenBackupUID/$sms_db_FILENAME") {

	my @msyncFilesToCopy;
	push @msyncFilesToCopy,"$sms_db_FILENAME"; 
	push @msyncFilesToCopy,"$AddressBook_sqlitedb_FILENAME"; 
	push @msyncFilesToCopy,"Info.plist"; 
	push @msyncFilesToCopy,"Manifest.plist"; 
	if (-e "$msyncBackups/$chosenBackupUID/Manifest.mbdb") {
		push @msyncFilesToCopy,"Manifest.mbdb"; 
	}
	if (-e "$msyncBackups/$chosenBackupUID/Manifest.db") {
		push @msyncFilesToCopy,"Manifest.db"; 
	}
	my $msyncUID = "$msyncBackups/$chosenBackupUID";
	my $destRoot = "$outputDirectory/copiedMsyncBackupFiles";
	foreach my $file (@msyncFilesToCopy) {
		copy ("$msyncUID/$file", "$destRoot/$file") or die "ERROR: Could not copy [$msyncUID/$file] to [$destRoot/$file]. $!";
	}

}


## Copy assuming 2 character sub directories. (iOS 10,11,12,13,14)
if (-e "$msyncBackups/$chosenBackupUID/3d/$sms_db_FILENAME" && "$msyncBackups/$chosenBackupUID/31/$AddressBook_sqlitedb_FILENAME") {

	my @msyncFilesToCopy;
	push @msyncFilesToCopy,"3d/$sms_db_FILENAME"; 
	push @msyncFilesToCopy,"31/$AddressBook_sqlitedb_FILENAME"; 
	push @msyncFilesToCopy,"Info.plist"; 
	push @msyncFilesToCopy,"Manifest.plist"; 
	push @msyncFilesToCopy,"Manifest.db"; 

	my $msyncUID = "$msyncBackups/$chosenBackupUID";
	my $destRoot = "$outputDirectory/copiedMsyncBackupFiles";

	foreach my $file (@msyncFilesToCopy) {
		my $copyFrom = "$msyncUID/$file";
		my $copyTo = "$destRoot/$file";

	
		
		if ($file eq "3d/$sms_db_FILENAME") { 
			$copyTo =~ s/3d\/$sms_db_FILENAME/$sms_db_FILENAME/;
			copy ("$copyFrom", "$copyTo") or die "ERROR: Could not copy [$copyFrom] to [$copyTo]. $!";
			next;
		}

		if ($file eq "31/$AddressBook_sqlitedb_FILENAME") { 
			$copyTo =~ s/31\/$AddressBook_sqlitedb_FILENAME/$AddressBook_sqlitedb_FILENAME/;
			copy ("$copyFrom", "$copyTo") or die "ERROR: Could not copy [$copyFrom] to [$copyTo]. $!";
			next;
		}		
		
		
		copy ("$copyFrom", "$copyTo") or die "ERROR: Could not copy [$msyncUID/$file] to [$destRoot/$file]. $!";
	}
	
}

## Check to see that files were copied. (redundant check)
# unless (-e "$outputDirectory/copiedMsyncBackupFiles/$sms_db_FILENAME") {
# 	die "Missing $outputDirectory/copiedMsyncBackupFiles/$sms_db_FILENAME cannot continue. $!";
# } 
# 
# unless (-e "$outputDirectory/copiedMsyncBackupFiles/$AddressBook_sqlitedb_FILENAME") {
# 	die "Missing $outputDirectory/copiedMsyncBackupFiles/$AddressBook_sqlitedb_FILENAME cannot continue. $!";
# } 
# 
# unless (-e "$outputDirectory/copiedMsyncBackupFiles/Info.plist") {
# 	die "Missing $outputDirectory/copiedMsyncBackupFiles/Info.plist cannot continue. $!";
# } 



## Get Device Name from the Info.plist we copied
my $Device_Name = getDeviceNameFromPlist("$outputDirectory/copiedMsyncBackupFiles/Info.plist");


#### Change Directory to the $outputDirectory
chdir ($outputDirectory) or die "\nERROR: Could not chdir to [$outputDirectory]. $!" ;


#### Create sub folders to store text files exported from SQL
## Check to see if already exists.  If so then quit.  This precaution to not overwrite anything.
if (-d "tableData") { die "\nERROR: Not expecting a folder to already be here.  Can't continue.  Foler is [tableData]"; }

## Create it
mkdir ("tableData") == 1 or die "$! \n\nERROR: Could not create [tableData].\n";;

## Make sure directory is writable.
unless (-d "tableData" && -w "tableData") { die "$! \n\nERROR: tableData folder does not exist or is not writeable.";}



#### Match phone number or email address to a contact name and organization and
#### build hashes for %numberName and %handleROWIDName.
### Get phone number or email address from handle.id in sms.db.  Use 
### ABPersonFullTextSearch_content table in AddressBook.sqlitedb to match 
### c16Phone with handle.id from sms.db.
my %numberName; ##%numberName{+15555555555} = "John Smith Some Organization"
my %handleROWIDName; ##%ROWIDName{1} = "John Smith Some Organization"


### Get list of phone numbers and email addresses, (unique values) to %handleid
## $handleid{rowid} = 5555555555;
## $handleid{rowid} = mike@email.com;

my $sqlCall_handleid="$sqlite3 \"$outputDirectory/copiedMsyncBackupFiles/$sms_db_FILENAME\"  \"
select ROWID, id from handle
order by ROWID
\"
";

#print "Executing sql:\n[$sqlCall_handleid]\n\n";

my %handleid;
foreach my $handleRow (`$sqlCall_handleid`) { 
	chomp $handleRow;

	my ($ROWID, $id) = split /\|/, $handleRow,2;
	#print "$ROWID, $id \n";
	$handleid{$ROWID} = $id;
}
## Do not continue if sqlCall failed.
if ($? != 0) { die "sql failed.  \$sqlCall_handleid was [$sqlCall_handleid].\n sqlite3 error code was $?. $!"; }


# foreach my $key (keys %handle_id) {
# 	print $key . "\n";
# }




##### get :
## %c16Phone{docid}
my %c16Phone;

my $sqlCall_c16Phone="$sqlite3 \"$outputDirectory/copiedMsyncBackupFiles/$AddressBook_sqlitedb_FILENAME\"	\"
select docid, c16Phone from ABPersonFullTextSearch_content
\"
";

foreach my $ABPFTS_contentRow (`$sqlCall_c16Phone`) {
	chomp $ABPFTS_contentRow;

	my ($docid, $c16Phone) = split /\|/, $ABPFTS_contentRow,2;
	#print "$docid, $c16Phone\n";
	$c16Phone{$docid} = $c16Phone;
}
## Do not continue if sqlCall failed.
if ($? != 0) { die "sql failed.  \$sqlCall_c16Phone was [$sqlCall_c16Phone].\n sqlite3 error code was $?. $!"; }

##### get :
## %c17Email{docid}
my %c17Email;

my $sqlCall_c17Email="$sqlite3 \"$outputDirectory/copiedMsyncBackupFiles/$AddressBook_sqlitedb_FILENAME\"	\"
select docid, c17Email from ABPersonFullTextSearch_content
\"
";

foreach my $ABPFTS_contentRow (`$sqlCall_c17Email`) {
	chomp $ABPFTS_contentRow;

	my ($docid, $c17Email) = split /\|/, $ABPFTS_contentRow,2;
	#print "$docid, $c16Phone\n";
	$c17Email{$docid} = $c17Email;
}
## Do not continue if sqlCall failed.
if ($? != 0) { die "sql failed.  \$sqlCall_c17Email was [$sqlCall_c17Email].\n sqlite3 error code was $?. $!"; }




## %c0First{docid}
my %c0First;

my $sqlCall_c0First="$sqlite3 \"$outputDirectory/copiedMsyncBackupFiles/$AddressBook_sqlitedb_FILENAME\"	\"
select docid, c0First from ABPersonFullTextSearch_content
\"
";

foreach my $ABPFTS_contentRow (`$sqlCall_c0First`) {
	chomp $ABPFTS_contentRow;

	my ($docid, $c0First) = split /\|/, $ABPFTS_contentRow,2;
	$c0First{$docid} = $c0First;
	#print "$docid, $c0First\n";
}
## Do not continue if sqlCall failed.
if ($? != 0) { die "sql failed.  \$sqlCall_c0First was [$sqlCall_c0First].\n sqlite3 error code was $?. $!"; }




## %c1Last{docid}
my %c1Last;

my $sqlCall_c1Last="$sqlite3 \"$outputDirectory/copiedMsyncBackupFiles/$AddressBook_sqlitedb_FILENAME\"	\"
select docid, c1Last from ABPersonFullTextSearch_content
\"
";

foreach my $ABPFTS_contentRow (`$sqlCall_c1Last`) {
	chomp $ABPFTS_contentRow;

	my ($docid, $c1Last) = split /\|/, $ABPFTS_contentRow,2;
	$c1Last{$docid} = $c1Last;

	#print "$docid, $c1Last\n";
}
## Do not continue if sqlCall failed.
if ($? != 0) { die "sql failed.  \$sqlCall_c1Last was [$sqlCall_c1Last].\n sqlite3 error code was $?. $!"; }



## %c6Organization{docid}
my %c6Organization;

my $sqlCall_c6Organization="$sqlite3 \"$outputDirectory/copiedMsyncBackupFiles/$AddressBook_sqlitedb_FILENAME\"	\"
select docid, c6Organization from ABPersonFullTextSearch_content

\"
";

foreach my $ABPFTS_contentRow (`$sqlCall_c6Organization`) {

	chomp $ABPFTS_contentRow;

	my ($docid, $c6Organization) = split /\|/, $ABPFTS_contentRow,2;
	$c6Organization{$docid} = $c6Organization;

}
## Do not continue if sqlCall failed.
if ($? != 0) { die "sql failed.  \$sqlCall_c6Organization was [$sqlCall_c6Organization].\n sqlite3 error code was $?. $!"; }




####  Loop through handle.ROWID (%handleid) and match handle.id to c16Phone

foreach my $handleROWID (keys %handleid) {

	my $HANDLEID = $handleid{$handleROWID};
	my $HANDLEIDquoted = quotemeta($HANDLEID);

	$numberName{$HANDLEID} = "NONAMEFOUND";
	$handleROWIDName{$handleROWID} = "NONAMEFOUND";

	foreach my $docid (keys %c16Phone){
		my $C16PHONE = $c16Phone{$docid};
		chomp $C16PHONE;
	


		if ($C16PHONE =~ / $HANDLEIDquoted /) {

			## only match handle.id that begins with a +
			next unless($HANDLEID =~ /^\+/);

# 			print "MATCHED $HANDLEIDquoted\n";
# 			print "\t$C16PHONE =~ $HANDLEIDquoted\n";
# 			print "\thandleROWID $handleROWID docid $docid handleid{$handleROWID} $handleid{$handleROWID}  c0First{$docid} $c0First{$docid} c1Last{$docid} $c1Last{$docid} \n";

			$numberName{$HANDLEID} = "$c0First{$docid} $c1Last{$docid} $c6Organization{$docid}";
			$handleROWIDName{$handleROWID} = $numberName{$HANDLEID};

		}
	}
	
	if ($numberName{$HANDLEID} eq "NONAMEFOUND") { 			$numberName{$HANDLEID} = "NONAMEFOUND ($HANDLEID)"; }
	if ($handleROWIDName{$handleROWID} eq "NONAMEFOUND") {	$handleROWIDName{$handleROWID} = "NONAMEFOUND ($HANDLEID)"; }

}


####  Loop through handle.ROWID (%handleid) and match handle.id to c17Email

foreach my $handleROWID (keys %handleid) {

	my $HANDLEID = $handleid{$handleROWID};
	my $HANDLEIDquoted = quotemeta($HANDLEID);

	foreach my $docid (keys %c17Email){
		my $c17Email = $c17Email{$docid};
		chomp $c17Email;
		if ($c17Email =~ /$HANDLEIDquoted/i) {

# 			print "MATCHED $HANDLEIDquoted\n";
# 			print "\t$c17Email =~ $HANDLEIDquoted\n";
# 			print "\thandleROWID $handleROWID docid $docid handleid{$handleROWID} $handleid{$handleROWID}  c0First{$docid} $c0First{$docid} c1Last{$docid} $c1Last{$docid} \n";

			$numberName{$HANDLEID} = "$c0First{$docid} $c1Last{$docid} $c6Organization{$docid}";
			$handleROWIDName{$handleROWID} = $numberName{$HANDLEID};

		}
	}
}








#### Tie message_id to a chat_id so we can get list of handle_id(s) associated with a message_id
my %chat_message_join__message_id;
## $chat_message_join__message_id{34756} = 689;

my $sqlCall_chat_message_join = "$sqlite3 -header -csv \"$outputDirectory/copiedMsyncBackupFiles/$sms_db_FILENAME\"	\"
select chat_id,message_id from chat_message_join\"
";


foreach my $chat_message_joinROW (`$sqlCall_chat_message_join`) { 
	chomp $chat_message_joinROW;
	my ($chat_id, $message_id) = split /,/,$chat_message_joinROW,2;
	$chat_message_join__message_id{$message_id} = $chat_id;
	#print" $chat_id, $message_id\n";
}
## Do not continue if sqlCall failed.
if ($? != 0) { die "ERROR: sql failed.  \$sqlCall_chat_message_join was [$sqlCall_chat_message_join].\n sqlite3 error code was $?. $!"; }



#### Get list of handle_id s associated with a chat_id
my %chat_handle_join__chat_id;

my $sqlCall_chat_handle_join = "$sqlite3 -header -csv \"$outputDirectory/copiedMsyncBackupFiles/$sms_db_FILENAME\"	\"
select chat_id,handle_id from chat_handle_join\"
";


foreach my $chat_handle_joinROW (`$sqlCall_chat_handle_join`) { 
	chomp $chat_handle_joinROW;
	my ($chat_id, $handle_id) = split /,/,$chat_handle_joinROW,2;
	$chat_handle_join__chat_id{$chat_id} .= "$handle_id ";
	#print" $chat_id, $message_id\n";
}
## Do not continue if sqlCall failed.
if ($? != 0) { die "ERROR: sql failed.  \$sqlCall_chat_handle_join was [$sqlCall_chat_handle_join].\n sqlite3 error code was $?. $!"; }


#### Output message table to csv file.  This file is not used but could be used for debugging.

## File to write to.
my $messageCSVfile = "$outputDirectory/tableData/$Device_Name-message.csv";

## sql call
my $sqlCall_messageTable = "$sqlite3 -header -csv \"$outputDirectory/copiedMsyncBackupFiles/$sms_db_FILENAME\"	\"
select ROWID, text, handle_id, subject, date, is_from_me from message
\" ";


## Make sure output file does not already exist.
if (-e $messageCSVfile) { die "\nERROR: Will not overwrite $messageCSVfile. $!"; }

## Open file for writing
open (my $messageCSVFH,">",$messageCSVfile) or die "\nERROR: Could not open for writing: [$messageCSVfile]. $!";
print $messageCSVFH "\x{ef}\x{bb}\x{bf}";  ## So excel will display unicode correctly.

## Execute SQL.
print $messageCSVFH `$sqlCall_messageTable`;

## Do not continue if sqlCall failed.
if ($? != 0) { die "ERROR: sql failed.  \$sqlCall_messageTable was [$sqlCall_messageTable].\n sqlite3 error code was $?. $!"; }





#### Output THE sms CSV file with outgoing phone number joined from handle table.

## File to write to.
my $messageWithJoinCSVfile = "$outputDirectory/tableData/$Device_Name-sms.csv";

## sql call

my $selectDate = "datetime(message.date / 1000000000 + 978307201,'unixepoch') as date"; ## Date select for iOS 14,13

if (getKeyValueFromPlist("$outputDirectory/copiedMsyncBackupFiles/Info.plist","Product Version") =~ /^10/) {
my $selectDate = "datetime(message.date + 978307201,'unixepoch') as date"; ## Date select for iOS 10
}

my $sqlCall_messageTableWithJoin = "$sqlite3 -header -csv \"$outputDirectory/copiedMsyncBackupFiles/$sms_db_FILENAME\"	\"

select 

message.ROWID, 
$selectDate,
message.handle_id, 
handle.id,
message.cache_roomnames,
message.is_from_me,
REPLACE(REPLACE(message.subject, x'0D','<crNEWLINE>'), x'0A', '<nlNEWLINE>') as 'subject', 
REPLACE(REPLACE(message.text, x'0D','<crNEWLINE>'), x'0A', '<nlNEWLINE>') as 'text'

from message

left join handle
on message.handle_id=handle.ROWID

order by message.ROWID

\"
";


## Make sure output file does not already exist.
if (-e $messageWithJoinCSVfile) { die "\nERROR: Will not overwrite $messageCSVfile. $!"; }

## Open file for writing
open (my $messageWithJoinCSVFH,">",$messageWithJoinCSVfile) or die "\nERROR: Could not open for writing: [$messageCSVfile]. $!";
print $messageWithJoinCSVFH "\x{ef}\x{bb}\x{bf}";  ## So excel will display unicode correctly.

## Execute SQL, writing to csv file.
print $messageWithJoinCSVFH `$sqlCall_messageTableWithJoin`;

## Do not continue if sqlCall failed.
if ($? != 0) { die "sql failed.  \$sqlCall_messageTableWithJoin was [$sqlCall_messageTableWithJoin].\n sqlite3 error code was $?. $!"; }

close $messageWithJoinCSVFH or die "Could not close $messageWithJoinCSVFH. $!";


#### Read CSV file, add contact names and output to new file.
my $messageCSVwithContacts = "$outputDirectory/tableData/$Device_Name-smsWithContacts.csv";
die if (-e $messageCSVwithContacts );
open ($messageWithJoinCSVFH,"<",$messageWithJoinCSVfile) or die "\nERROR: Could not open [$messageWithJoinCSVfile] for reading. $!";

open (my $messageCSVwithContactsFH, ">",$messageCSVwithContacts) or die "\nERROR: Could not open [$messageCSVwithContacts] for writing. $!";
print $messageCSVwithContactsFH "\x{ef}\x{bb}\x{bf}";  ## So excel will display unicode correctly.
print $messageCSVwithContactsFH "ROWID,date,handle_id,id,contactName,is_from_me,subject,text\n";

while (my $csvLine = <$messageWithJoinCSVFH>) {
	next if $. == 1; # Skip first line
	my ($ROWID,$date,$handle_id,$id,$cache_roomnames,$restOfline) = split /,/,$csvLine, 6;
	my $contactName="$id"; ## use $id instead of NONAMEFOUND
	if ($numberName{$id}) { $contactName = $numberName{$id} }


	## If $handle_id = 0 then this is a chat or group message.  Will need to use chat table to determine message recipient(s)
	## relevent columns are message.cache_roomnames and chat.chat_identifier
	if ($handle_id == 0) {
		$contactName = "Me to ... ";		
	}

	print $messageCSVwithContactsFH "$ROWID,$date,$handle_id,$id,$contactName,$restOfline";
}

close ($messageWithJoinCSVFH) or die "\nERROR: Could not close $messageWithJoinCSVFH. $!";



#### Read CSV file, add new columes and output new CSV file.
#### ROWID Date From To Subject Text
####
#### Note handle_id of 0 indicates that this is a text from me to multiple recipients.

my $messageCSVwithToFrom = "$outputDirectory/$Device_Name-smsWithToFrom.csv";
if (-e $messageCSVwithToFrom) { die "\nERROR: File exists, will not overwrite [$messageCSVwithToFrom]. $!"};

open ($messageWithJoinCSVFH,"<",$messageWithJoinCSVfile) or die "\nERROR: Could not open [$messageWithJoinCSVfile] for reading. $!";

open (my $messageCSVwithToFromFH, ">",$messageCSVwithToFrom) or die "\nERROR: Could not open [$messageCSVwithContacts] for writing. $!";

## Output BOM otherwise Excel may not display UTF-8 unicode characters correctly.
print $messageCSVwithToFromFH "\x{ef}\x{bb}\x{bf}";  ## So excel will display unicode correctly.

## Output column names.
print $messageCSVwithToFromFH "ROWID,date,id,From,To,subject,text\n"; 

## Loop through the $outputDirectory/sms.csv file line by line, add 'from' and 'to' column data and output to the new file.
while (my $csvLine = <$messageWithJoinCSVFH>) {
	next if $. == 1; # Skip column headers on first line.
	chomp $csvLine;
	
	my ($ROWID,$date,$handle_id,$id,$cache_roomnames,$is_from_me,$subject,$text) = split /,/,$csvLine, 8;

	## 
	if ($id eq "") { $id = "me";}
	
	print $messageCSVwithToFromFH "$ROWID,$date,$id";


	#### 'From' Column.
	my $fromValue ="NONAMEFOUND"; 
	if ($handle_id == 0) {
		$fromValue = "me";
	} else {	
		if ($is_from_me == 1) { $fromValue = "me"; } 
		if ($is_from_me == 0) { $fromValue = "$numberName{$id}"; } 
	}
	$fromValue =~ s/\"/\"\"/g; ## Escape quotes for csv compatibility.
	print $messageCSVwithToFromFH ",\"$fromValue\"";



	#### To Column
	my $toValue = "ME";

	## if handle_id is 0 then this is a group chat sent from me to multiple peeps.
	if ($handle_id == 0) {
		$toValue = "group of peeps"; ## can remove this line later
		if ($chat_message_join__message_id{$ROWID}) {
			my $chat_id = $chat_message_join__message_id{$ROWID};
			$toValue = $chat_handle_join__chat_id{$chat_id};
			#$toValue =~ s/ $//;
			my @toValues = split /\s/,$toValue;
			if (scalar @toValues > 1) {
				$toValue = "";
				foreach my $handle_id (@toValues) { 
					#aaa
					if ($handleROWIDName{$handle_id}) {
						$toValue .= "[$handleROWIDName{$handle_id}]"; 
					}
				}
			}
		}
	} else {
	
		## Check to see if multiple handle_id associated with chat_id <- message_id
		my $chat_id = $chat_message_join__message_id{$ROWID};
		if ($chat_id) {
			#$chat_handle_join__chat_id{$chat_id}
			$toValue = $chat_handle_join__chat_id{$chat_id}; 
			my @toValues = split /\s/,$toValue;

				if (scalar @toValues > 1) {
					$toValue = "";
					foreach my $handle_id (@toValues) { 
						
						if ($handleROWIDName{$handle_id}) {
							$toValue .= "[$handleROWIDName{$handle_id}]"; 
						}

					}

				} else {
					if ($is_from_me == 1) { $toValue = "$numberName{$id}"; } 
					if ($is_from_me == 0) { $toValue = "me"; } 
				}

			}

		}
	
	$toValue =~ s/\"/\"\"/g; ## Escape quotes for csv compatibility.			 
	print $messageCSVwithToFromFH ",\"$toValue\"";


	#### Output the rest of columns (subject, text).

	## Put newlines and carriage returns back in.
	
	if ($subject =~ /<nlNEWLINE>/) {
		unless ($subject =~ /^"/ && $subject =~ /"$/) {	$subject = "\"$subject\"" ; }
		$subject =~ s/<nlNEWLINE>/\n/g;
	}
	if ($subject =~ /<crNEWLINE>/) {
		unless ($subject =~ /^"/ && $subject =~ /"$/) {	$subject = "\"$subject\"" ; }
		$subject =~ s/<crNEWLINE>/\n/g;
	}

	if ($text =~ /<nlNEWLINE>/) {
		unless ($text =~ /^"/ && $text =~ /"$/) {	$text = "\"$text\"" ; }
		$text =~ s/<nlNEWLINE>/\n/g;
	}
	if ($text =~ /<crNEWLINE>/) {
		unless ($text =~ /^"/ && $text =~ /"$/) {	$text = "\"$text\"" ; }
		$text =~ s/<crNEWLINE>/\n/g;
	}
	

	print $messageCSVwithToFromFH ",$subject,$text\n";

}






print "\n$thisScript completed at " . localtime . "\n";
print "\nsmsExports are located at:\n\n$smsExportsDirectory\nand\n$outputDirectory\n\n";


print "Press RETURN to open the smsExports '$smsExportRanAt' folder.\n";
<STDIN>;

if ($macOS) {
	system("open ./");
}

if ($MSwin) {
	system("start .\\");
}



##############################################################################
#### Subroutines
##############################################################################

sub getDeviceNameFromPlist {
	#### Retrieve Device Name from Info.plist.  First try PlistBuddy.  If PlistBuddy fails attempt to parse the file manually.

	my $plistFile = $_[0];
	unless ($plistFile) { warn "No argument supplied to getDeviceNameFromPlist subroutine. $!"; }
	unless (-r $plistFile) { warn "Could not read $plistFile $!"; }
	my $Device_Name = "Device name not found";
	
	## Use PlistBuddy
	my $PlistBuddy = "/usr/libexec/PlistBuddy";
	if (-x $PlistBuddy) {
		$Device_Name = `/usr/libexec/PlistBuddy -c "Print 'Device Name'" "$plistFile" 2>/dev/null`; 
		chomp $Device_Name;
		
		## If PlistBuddy executed without error then use then return the Device Name value.
		if ($? == 0) {
			return $Device_Name;
		} 
	}
	

	
	
	## Attempt to parse the Info.plist file.
	my $loopFlag = 0;
	my $plistLine;
	
	unless (-r "$plistFile") {
		return "No Plist found or could not read [$plistFile]";
	}

	open (plistFH, "<", $plistFile);
	while (my $plistLine = <plistFH>) {
		chomp $plistLine;

		if ($loopFlag == 1) {
			$Device_Name = $plistLine;
			last;
		}

		if ($plistLine =~ m/<key>Device Name<\/key>/i) { 
			$loopFlag = 1; 
		}
	}
	close plistFH;

	$Device_Name =~ s/.*<string>//s;
	$Device_Name =~ s/<\/string>.*//s;

	return $Device_Name;

}



sub getKeyValueFromPlist {
	#### Retrieve the value of a key from Info.plist.  First try PlistBuddy.  If PlistBuddy fails attempt to parse the file manually.

	my $plistFile = $_[0];
	my $keyName = $_[1];
	unless ($plistFile) { warn "No argument supplied to getDeviceNameFromPlist subroutine. $!"; }
	unless (-r $plistFile) { warn "Could not read $plistFile $!"; }
	my $keyValue = "";
	
	## Use PlistBuddy
	my $PlistBuddy = "/usr/libexec/PlistBuddy";
	if (-x $PlistBuddy) {
		$keyValue = `/usr/libexec/PlistBuddy -c "Print '$keyName'" "$plistFile" 2>/dev/null`; 
		chomp $keyValue;
		
		## If PlistBuddy executed without error then use then return the Device Name value.
		if ($? == 0) {
			return $keyValue;
		} 
	}
	

	
	
	## Attempt to parse the Info.plist file.
	my $loopFlag = 0;
	my $plistLine;
	
	unless (-r "$plistFile") {
		return "No Plist found or could not read [$plistFile]";
	}

	open (plistFH, "<", $plistFile);
	while (my $plistLine = <plistFH>) {
		chomp $plistLine;

		if ($loopFlag == 1) {
			$Device_Name = $plistLine;
			last;
		}

		if ($plistLine =~ m/<key>$keyValue<\/key>/i) { 
			$loopFlag = 1; 
		}
	}
	close plistFH;

	$keyValue =~ s/.*<string>//s;
	$keyValue =~ s/<\/string>.*//s;

	return $keyValue;

}





sub returnTimestamp {
	## return a time value in the form yyyymmdd-hhmmss.txt

	my $timeValue = $_[0];
	my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime ($timeValue);
	
	$year += 1900;
	my $month = $mon+1;
	$month = sprintf("%02d",$month);
	my $day = sprintf("%02d",$mday);
	$hour = sprintf("%02d",$hour);
	$min = sprintf("%02d",$min);
	$sec = sprintf("%02d",$sec);
	return "$year$month$day-$hour$min$sec";

}




sub presentBackups {
	## Present to user what we found and allow selection of which backup UID to use.

	print "\nFound backup(s) in:\n[$msyncBackups]\n\nWhich backup do you want to use? \n\n";
	foreach  my $i (0 .. $#keys_msyncBackupFiles - 1 ) {

		my $UID = $keys_msyncBackupFiles[$i];
		#print "Getting Device Name from $msyncBackups/$keys_msyncBackupFiles[$i]/Info.plist\n";

		my $Device_Name = getDeviceNameFromPlist("$msyncBackups/$UID/Info.plist");

		print $i + 1 . ") [$Device_Name]\n\tUID: $UID\n\tLast Modified: " . returnTimestamp($vals_msyncBackupFiles[$i]) . " \n";
		#print " [$Device_Name]\n";
	}

	#print scalar @keys_msyncBackupFiles+1 . ") [" . getDeviceNameFromPlist("$msyncBackups/$mostRecentBackupUID/Info.plist") . "]\n\t$mostRecentBackupUID (MOST RECENT)\n\n";
	print scalar @keys_msyncBackupFiles . ") [" . getDeviceNameFromPlist("$msyncBackups/$mostRecentBackupUID/Info.plist") . "] (MOST RECENT) \n";
	print "\tUID: $mostRecentBackupUID\n\t" . returnTimestamp($vals_msyncBackupFiles[$#vals_msyncBackupFiles]) . " (MOST RECENT)\n\n";
}
