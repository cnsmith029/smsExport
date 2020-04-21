#!/usr/bin/perl

use strict;
use warnings;
use Cwd;
require Cwd;


my $thisScript = "smsExport-1.0.2.pl";
## Version 1 should work with iOS Version 11 through 13  
## 	iOS V 11 - Confirmed
## 	iOS V 13.3.1 - Confirmed


###############################################################################
#### Global variables

#### Directory Locations

## iOS backup directory
my $msyncBackups = "$ENV{'HOME'}/Library/Application Support/MobileSync/Backup";
## This is defines we will copy files from msyncBackups and also output CSV file.
my $smsExportsDirectory = "$ENV{'HOME'}/smsExports";


#### Database file names

my $sms_db_FILENAME =  "3d0d7e5fb2ce288813306e4d4636395e047a3d28"; ## sms.db  sqlite DB where messages stored. Name of backup file in MobileSync/Backups
my $ab_db_FILENAME = "31bb7ba8914766d4ba40d6dfb6113c8b614be442"; ## AddressBook.sqlitedb   sqlite DB where AddressBook.sqlitedb aka Contacts stored.  Name of backup file in MobileSync/Backups


#### Other Global Vars

my $debugYes;
my $userInputDirectory; ## The folder specified by user at runtime or in opening menu.

#### Global variables
###############################################################################





print "\n -----------------------------------------------------------\n";
print "| Running $thisScript at " . localtime . "\n";

print "|
| $thisScript will read iOS backup files.  It will then attempt to
| export all messages in the SMS database into one CSV file.  This could be
| a big file if you are popular.  Note that only text is exported.
| Pictures and other attachments or multimedia are NOT exported.
 -----------------------------------------------------------\n\n\n";

## Check if run with -v flag and set $debugYes which will output extra DEBUG info.
if ($ARGV[0] && $ARGV[0] eq "-v") {	$debugYes = 1; shift @ARGV; print "NOTICE: Verbose mode engaged.\n"; }


if ($ARGV[0] && $ARGV[0] ne "-v" ) {
	$userInputDirectory = $ARGV[0];
	#$userInputDirectory =~ s/\\ //g;  ## Remove space escape.  Let only be space.

	if ($userInputDirectory =~ m/\*/) {
		print "Sorry, wildcards not allowed when specifying directories.  Exiting.\n";
		exit;
		#undef $userInputDirectory;
	}

	if ($userInputDirectory) {
		if (-d $userInputDirectory) {
			$msyncBackups = $userInputDirectory;
		} else {
			print "Directory [$userInputDirectory] does not exist.  Exiting.\n";
			exit;
		}
	}

	if ($debugYes) { print "DEBUG: msyncBackupsFromUser was [$userInputDirectory]\n"; }
}

## Print debug info
if ($debugYes) { print "DEBUG: smsExportsDirectory is [$smsExportsDirectory]\n"; }
if ($debugYes) { print "DEBUG: msyncBackups is [$msyncBackups]\n"; }


#### Ask user if default MobileSync Backup folder is ok, or do they want to specify.

print "Use MobileSync Backup folder at:\n[$msyncBackups]\n\n";
print "Press return or enter to continue.  Q to quit.  Or specify full path to the folder of backup UIDs you want to use.\n";
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



#### Get list of UID directories.  Then parse each Info.plist to get Device Name and present to user.

opendir(DIRH, "$msyncBackups") or die "ERROR: Can't open [$msyncBackups]. $!";
my @listOfFiles = readdir DIRH;
close DIRH;

my @listOfbackupUIDs;
foreach my $dirEntry (@listOfFiles) {
	chomp $dirEntry;  ## Remove newline character just incase we get one.
	next if ($dirEntry =~ m/^\./); ## Ignore invisible files or directory entries ( .somefile OR . OR .. OR anything beginning with a .)
	next unless (-r "$msyncBackups/$dirEntry/Info.plist"); ## Ignore directories that are without an Info.plist.
	push @listOfbackupUIDs, "$dirEntry";
}


unless (@listOfbackupUIDs) { die "ERROR: Could not get list of backups from [$msyncBackups].\n\nExiting.\n";}


if ($debugYes) { print "DEBUG: backupsFound\n"; foreach ( @listOfbackupUIDs) { print "  [$msyncBackups/$_]\n";} }


## Get modification date of all Info.plists into hashDatebackupUID
my %hashDatebackupUID; ## key is date of Info.Plist Value is backupUID
my $plistWasFound; ## Flag to show we found at least 1 Info.plist.

foreach (@listOfbackupUIDs) {
	chomp;

	## Print debug info
	if ($debugYes) { print "DEBUG: listOfbackupUIDs array line [$_]\n"; }

	if (-r "$msyncBackups/$_/Info.plist") {$plistWasFound = 1;}
	my 	($dev,$ino,$mode,$nlink,$uid,$gid,$rdev,$size,$atime,$mtime,$ctime,$blksize,$blocks)
		= stat("$msyncBackups/$_/Info.plist") or print "ERROR-info Could not stat '$msyncBackups/$_/Info.plist'\n";
	 ## Print debug info
	if ($debugYes) { print "DEBUG: hashDatebackupUID{$mtime} = $_\n";}
	$hashDatebackupUID{$mtime} = $_;
}


## Check to see at least one Info.plist was found.  If not then error out.
unless ($plistWasFound ) { die "ERROR: no Info.plist(s) were found OR or are readable.  Looked in [$msyncBackups/*/Info.plist]\n" }


## Sort hashDatebackupUID into array @infoPlistSortedByDate
my @infoPlistSortedByDate;
for my $key (sort keys %hashDatebackupUID) {
	push @infoPlistSortedByDate, $hashDatebackupUID{$key};
	if ($debugYes) { print "DEBUG: hashDatebackupUID{key} is [$hashDatebackupUID{$key}]\n";}
	
}


## Get the most recent backup UID folder to present to user.
my $mostRecentBackupUID = pop @infoPlistSortedByDate;
foreach (@infoPlistSortedByDate) {
}


## Present to user what we found and allow selection of which backup UID to use.
print "\nFound backup(s) in:\n[$msyncBackups]\n\nWhich backup UID do you want to use? \n\n";
foreach (@infoPlistSortedByDate) {
	my $UID = $_;
	my $Device_Name = getDeviceNameFromPlist("$msyncBackups/$_/Info.plist");

	print "UID: $UID ";
	print "[$Device_Name]\n";
}

print "UID: $mostRecentBackupUID [" . getDeviceNameFromPlist("$msyncBackups/$mostRecentBackupUID/Info.plist") . "] (MOST RECENT)\n\n";

print "Press return to use most recent OR specify a UID. q to quit:\nUID:" ;


my $chosenBackupUID = <STDIN>;
chomp $chosenBackupUID;


## If user typed q or Q (return) then exit.
if ($chosenBackupUID eq "q" || $chosenBackupUID eq "Q") {
	print "Done.  No files were copied or created.\n";
	exit;
} 

## If user pressed return without typing anything else, then assume wants mostRecentBackupUID
if ($chosenBackupUID eq "") {
	$chosenBackupUID = $mostRecentBackupUID
} 

## Print debug info
if ($debugYes) { print "DEBUG: chosenBackupUID [$chosenBackupUID] is at [$msyncBackups/$chosenBackupUID]\n"; }

## Verify that chosenbackupUID exists, otherwise error out.
unless (-e "$msyncBackups/$chosenBackupUID") { die "\n\nERROR: $msyncBackups/" . quotemeta($chosenBackupUID) . " does not exist.\n" }



#### Make sure smsExportsDirectory exists, otherwise create it.
unless (-d "$smsExportsDirectory") {

	mkdir ($smsExportsDirectory) == 1 or die "$! \nERROR: Could not create [$smsExportsDirectory].";

	if ($debugYes) { print "DEBUG: Created new folder [$smsExportsDirectory].\n"; }

}


#### Make sure smsExportsDirectory is writeable.
unless (-d "$smsExportsDirectory" && -w "$smsExportsDirectory") {
	die "$! \nERROR: output directory [$smsExportsDirectory] does not exist OR is not writeable.\n";
}

if ($debugYes) { print "DEBUG: smsExportsDirectory [$smsExportsDirectory] exists and is writable.\n"; }



#### Create subdirectory for output in smsExportsDirectory. In the form
#### /Users/mark/smsHistory/timestamp

## Get current time as timeStamp variable
my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime(time);
$year += 1900; $mon = $mon +1;
$mon= sprintf ("%02d", $mon);
$mday= sprintf ("%02d", $mday);
$hour= sprintf ("%02d", $hour);
$min= sprintf ("%02d", $min);
$sec= sprintf ("%02d", $sec);
my $timeStamp = "$year$mon$mday-$hour$min$sec";

## Define outputDirectory and make sure does not already exist.
my $outputDirectory = "$smsExportsDirectory/$timeStamp";
if (-d "$outputDirectory") {
	die "ERROR: Directory already exists, cannot create [$outputDirectory]. $!";
}

mkdir ($outputDirectory) == 1 or die "$! \nERROR: Could not create [$outputDirectory].\n";

## Print debug info
if ($debugYes) { print "DEBUG: outputDirectory created '$outputDirectory'\n";}

#### Copy database files from MobileSync/Backup directory into smsHistory Directory

## Create subfolder in outputDirectory for copied files from MobileSync/backup

unless (-d "$outputDirectory/copiedMsyncBackupFiles") {
	mkdir ("$outputDirectory/copiedMsyncBackupFiles") == 1 or die "$! \nERROR: Could not create [$outputDirectory/copiedMsyncBackupFiles].\n";
	if ($debugYes) { print "DEBUG: Created new folder at [$outputDirectory/copiedMsyncBackupFiles] .\n";}
}

## Copy DB files from MobilSync backups to working directory.
# my $tempDirFrom = "$msyncBackups/$chosenBackupUID/3d";
# my $tempFileFrom = $sms_db_FILENAME;
# my $tempcopyToDir = "$outputDirectory/copiedMsyncBackupFiles";
# my $tempcopyToName = $sms_db_FILENAME;

copyFileUsingOpen("$msyncBackups/$chosenBackupUID/3d",$sms_db_FILENAME,"$outputDirectory/copiedMsyncBackupFiles",$sms_db_FILENAME); 

copyFileUsingOpen("$msyncBackups/$chosenBackupUID/31",$ab_db_FILENAME,"$outputDirectory/copiedMsyncBackupFiles",$ab_db_FILENAME); 

copyFileUsingOpen("$msyncBackups/$chosenBackupUID","Info.plist","$outputDirectory/copiedMsyncBackupFiles","Info.plist"); 



	#system ("cp -pir \"$msyncBackups/$chosenBackupUID/3d/$sms_db_FILENAME\" $outputDirectory/copiedMsyncBackupFiles") == 0 or die "$! \nERROR: Could not copy [$msyncBackups/$chosenBackupUID/3d/$sms_db_FILENAME] to [$outputDirectory/copiedMsyncBackupFiles].";
	#system ("cp -pir \"$msyncBackups/$chosenBackupUID/31/$ab_db_FILENAME\" $outputDirectory/copiedMsyncBackupFiles") == 0 or die "$! \nERROR: Could not copy AddressBook_sqlitedb\n$msyncBackups/$chosenBackupUID/31/$ab_db_FILENAME to [$outputDirectory/copiedMsyncBackupFiles].";
	#system ("cp -pir \"$msyncBackups/$chosenBackupUID/Info.plist\" $outputDirectory/copiedMsyncBackupFiles") == 0 or die "$! \nERROR: Could not copy Info.plist\n$msyncBackups/$chosenBackupUID/Info.plist\" [$outputDirectory/copiedMsyncBackupFiles].";
## maybe don't really need Manifest.db	system ("cp -pir \"$msyncBackups/$chosenBackupUID/Manifest.db\" $outputDirectory/copiedMsyncBackupFiles") == 0 or die "ERROR: Could not copy Manifest.db\n$msyncBackups/$chosenBackupUID/Manifest.db\" $outputDirectory/copiedMsyncBackupFiles\n";

## Get Device Name from the Info.plist we copied
my $Device_Name = getDeviceNameFromPlist("$outputDirectory/copiedMsyncBackupFiles/Info.plist");

if ($debugYes) { print "DEBUG: Device_Name is [$Device_Name].\n";}


#### Change Directory to the $outputDirectory
chdir ($outputDirectory) or die "ERROR Could not chdir to [$outputDirectory]. $!" ;
if ($debugYes) { print "DEBUG: Current working directory (getcwd) is [" . getcwd . "].\n";}


#### Create sub folders to store text files exported from SQL
## Check to see if already exists.  If so then quit.  This precaution to not overwrite anything.
if (-d "tableData") { die "ERROR: Not expecting a folder to already be here.  Can't continue.  Foler is [tableData]"; }
## Create it
mkdir ("tableData") == 1 or die "$! \nERROR: Could not create [tableData].\n";;

## Check to see it is writeable directory.
unless (-d "tableData" && -w "tableData") { die "$! \nERROR: tableData folder does not exist or is not writeable.";}

if ($debugYes) { print "DEBUG: Created folder [tableData].\n";}




####  Export some columns from the message table in the sms_db_FILENAME to a text file using | as field delimiter.

my $sqlCallTextMessages = "sqlite3 copiedMsyncBackupFiles/$sms_db_FILENAME \"select 
 ROWID, 
 date, 
 is_from_me, 
 handle_id,
 REPLACE(subject, '|', 'PIPESYMBOL'),
 REPLACE(REPLACE(text, x'0A', '<nlNEWLINE>'), x'0D','<crNNEWLINE>'),
 cache_roomnames
 from message
 order by ROWID\"";

## Make sure MESSAGE.txt file does not exist.
if (-e "tableData/MESSAGE.txt") { die "ERROR: will not overwrite. Delete [tableData/MESSAGE.txt] and try again. $! "} 
## Execute Sql.

system("$sqlCallTextMessages 1>>tableData/MESSAGE.txt") == 0 or die "ERROR: Could not execute SQL, [$sqlCallTextMessages]. $!";
if ($debugYes) { print "DEBUG: sql call was [$sqlCallTextMessages 1>>tableData/MESSAGE.txt]\n";}

##############################################################################
############ Output a selection of columns, each to individual CSV file.

my $db; ## sqlDB file. i.e. 3d0d7e5fb2ce288813306e4d4636395e047a3d28
my $table; ## table we will get column from i.e. message
my $indexColumn; ## IMPORTANT must chose name of column considered to be the row index i.e. ROWID
my $columnToSelect;  ## i.e. handle_id 
my $columnToSelectWithReplace; ## select portion of statment with replace funciton
my $orderByColumn; ## Column to sort by i.e. ROWID
my $outputFile;  ## text file we will write to

my $sqlError;


######## From sms.db
$db = "copiedMsyncBackupFiles/$sms_db_FILENAME";

#### handle.handle.id
$table = "handle";
$indexColumn = "ROWID";
$columnToSelect = "id"; ## variable on same table
$columnToSelectWithReplace = "REPLACE(REPLACE($columnToSelect, x'0A', '<NNEWLINE>'), x'0D','<NNEWLINE>')";  ## variable on same table ## Optional but might make sense to keep all the same.
$orderByColumn = $indexColumn;
$outputFile = "tableData/$columnToSelect-$table.csv";  ## variable on same table

$sqlError = outputColumnToFile($db,$table,$indexColumn,$columnToSelectWithReplace,$orderByColumn,$outputFile);
if ($sqlError) { print "ERROR: sql call falied. $sqlError\n"; die; }



#### chat.guid
$table = "chat";
$indexColumn = "ROWID";
$columnToSelect = "guid"; ## variable on same table
$columnToSelectWithReplace = "$columnToSelect";  ## variable on same table ## Optional but might make sense to keep all the same.
$orderByColumn = $indexColumn;
$outputFile = "tableData/$columnToSelect-$table.csv"; 

$sqlError = outputColumnToFile($db,$table,$indexColumn,$columnToSelectWithReplace,$orderByColumn,$outputFile);
if ($sqlError) { print "ERROR: sql call falied. $sqlError\n"; die; }



#### chat.chat_identifier
$table = "chat";
$indexColumn = "ROWID";
$columnToSelect = "chat_identifier"; ## variable on same table
$columnToSelectWithReplace = "chat_identifier";  ## variable on same table ## Optional but might make sense to keep all the same.
$orderByColumn = $indexColumn;
$outputFile = "tableData/$columnToSelect-$table.csv"; 

$sqlError = outputColumnToFile($db,$table,$indexColumn,$columnToSelectWithReplace,$orderByColumn,$outputFile);
if ($sqlError) { print "ERROR: sql call falied. $sqlError\n"; die; }


#### chat.service_name
$table = "chat";
$indexColumn = "ROWID";
$columnToSelect = "service_name"; ## variable on same table
$columnToSelectWithReplace = "service_name";  ## variable on same table ## Optional but might make sense to keep all the same.
$orderByColumn = $indexColumn;
$outputFile = "tableData/$columnToSelect-$table.csv"; 

$sqlError = outputColumnToFile($db,$table,$indexColumn,$columnToSelectWithReplace,$orderByColumn,$outputFile);
if ($sqlError) { print "ERROR: sql call falied. $sqlError\n"; die; }



#### chat.room_name
$table = "chat";
$indexColumn = "ROWID";
$columnToSelect = "room_name"; ## variable on same table
$columnToSelectWithReplace = "room_name";  ## variable on same table ## Optional but might make sense to keep all the same.
$orderByColumn = $indexColumn;
$outputFile = "tableData/$columnToSelect-$table.csv"; 

$sqlError = outputColumnToFile($db,$table,$indexColumn,$columnToSelectWithReplace,$orderByColumn,$outputFile);
if ($sqlError) { print "ERROR: sql call faliedddd. $sqlError\n"; die; }



#### chat_handle_join.handle_id
$table = "chat_handle_join";
$indexColumn = "chat_id";  ## NOTE in this table (chat_handle_join) chat_id is not unique, but should leave orderByColumn in for subroutine compatibility 
$columnToSelect = "handle_id"; ## variable on same table
$columnToSelectWithReplace = "$columnToSelect";  ## variable on same table ## Optional but might make sense to keep all the same.
$orderByColumn = $indexColumn;
$outputFile = "tableData/$columnToSelect-$table.csv"; 

$sqlError = outputColumnToFile($db,$table,$indexColumn,$columnToSelectWithReplace,$orderByColumn,$outputFile);
if ($sqlError) { print "ERROR: sql call falied. $sqlError\n"; die; }





######## From AddressBook.sqlitedb 
$db = "copiedMsyncBackupFiles/$ab_db_FILENAME";

#### ABPersonFullTextSearch_content.c0First
$table = "ABPersonFullTextSearch_content";
$indexColumn = "docid";
$columnToSelect = "c0First"; ## variable on same table
$columnToSelectWithReplace = "REPLACE(REPLACE($columnToSelect, x'0A', '<NNEWLINE>'), x'0D','<NNEWLINE>')";  ## variable on same table ## Optional but might make sense to keep all the same.
$orderByColumn = $indexColumn;
$outputFile = "tableData/$columnToSelect-$table.csv";  ## variable on same table

$sqlError = outputColumnToFile($db,$table,$indexColumn,$columnToSelectWithReplace,$orderByColumn,$outputFile);
if ($sqlError) { print "ERROR: sql call falied. $sqlError\n"; die; }



#### ABPersonFullTextSearch_content.c1Last
$table = "ABPersonFullTextSearch_content";
$indexColumn = "docid";
$columnToSelect = "c1Last"; ## variable on same table
$columnToSelectWithReplace = "REPLACE(REPLACE($columnToSelect, x'0A', '<NNEWLINE>'), x'0D','<NNEWLINE>')"; 
$outputFile = "tableData/$columnToSelect-$table.csv";  ## variable on same table

$sqlError = outputColumnToFile($db,$table,$indexColumn,$columnToSelectWithReplace,$orderByColumn,$outputFile);
if ($sqlError) { print "ERROR: sql call falied. $sqlError\n"; die; }



#### ABPersonFullTextSearch_content.c6Organization
$table = "ABPersonFullTextSearch_content";
$indexColumn = "docid";
$columnToSelect = "c6Organization"; ## variable on same table
$columnToSelectWithReplace = "REPLACE(REPLACE($columnToSelect, x'0A', '<NNEWLINE>'), x'0D','<NNEWLINE>')"; 
$outputFile = "tableData/$columnToSelect-$table.csv";  ## variable on same table

$sqlError = outputColumnToFile($db,$table,$indexColumn,$columnToSelectWithReplace,$orderByColumn,$outputFile);
if ($sqlError) { print "ERROR: sql call falied. $sqlError\n"; die; }



#### ABPersonFullTextSearch_content.c16Phone
$table = "ABPersonFullTextSearch_content";
$indexColumn = "docid";
$columnToSelect = "c16Phone"; ## variable on same table
$columnToSelectWithReplace = "REPLACE(REPLACE($columnToSelect, x'0A', '<NNEWLINE>'), x'0D','<NNEWLINE>')"; 
$outputFile = "tableData/$columnToSelect-$table.csv";  ## variable on same table

$sqlError = outputColumnToFile($db,$table,$indexColumn,$columnToSelectWithReplace,$orderByColumn,$outputFile);
if ($sqlError) { print "ERROR: sql call falied. $sqlError\n"; die; }



#### ABPersonFullTextSearch_content.c17Email
$table = "ABPersonFullTextSearch_content";
$indexColumn = "docid";
$columnToSelect = "c17Email"; ## variable on same table
$columnToSelectWithReplace = "REPLACE(REPLACE($columnToSelect, x'0A', '<NNEWLINE>'), x'0D','<NNEWLINE>')"; 
$outputFile = "tableData/$columnToSelect-$table.csv";  ## variable on same table

$sqlError = outputColumnToFile($db,$table,$indexColumn,$columnToSelectWithReplace,$orderByColumn,$outputFile);
if ($sqlError) { print "ERROR: sql call falied. $sqlError\n"; die; }



#### ABPerson.First
$table = "ABPerson";
$indexColumn = "ROWID";
$columnToSelect = "First"; ## variable on same table
$columnToSelectWithReplace = "REPLACE(REPLACE($columnToSelect, x'0A', '<NNEWLINE>'), x'0D','<NNEWLINE>')";  ## variable on same table ## Optional but might make sense to keep all the same.
$orderByColumn = $indexColumn;
$outputFile = "tableData/$columnToSelect-$table.csv";  ## variable on same table

$sqlError = outputColumnToFile($db,$table,$indexColumn,$columnToSelectWithReplace,$orderByColumn,$outputFile);
if ($sqlError) { print "ERROR: sql call falied. $sqlError\n"; die; }



#### ABPerson.Last
$table = "ABPerson";
$indexColumn = "ROWID";
$columnToSelect = "Last"; ## variable on same table
$columnToSelectWithReplace = "REPLACE(REPLACE($columnToSelect, x'0A', '<NNEWLINE>'), x'0D','<NNEWLINE>')";  ## variable on same table ## Optional but might make sense to keep all the same.
$orderByColumn = $indexColumn;
$outputFile = "tableData/$columnToSelect-$table.csv";  ## variable on same table

$sqlError = outputColumnToFile($db,$table,$indexColumn,$columnToSelectWithReplace,$orderByColumn,$outputFile);
if ($sqlError) { print "ERROR: sql call falied. $sqlError\n"; die; }



#### ABPerson.Organization
$table = "ABPerson";
$indexColumn = "ROWID";
$columnToSelect = "Organization"; ## variable on same table
$columnToSelectWithReplace = "REPLACE(REPLACE($columnToSelect, x'0A', '<NNEWLINE>'), x'0D','<NNEWLINE>')";  ## variable on same table ## Optional but might make sense to keep all the same.
$orderByColumn = $indexColumn;
$outputFile = "tableData/$columnToSelect-$table.csv";  ## variable on same table

$sqlError = outputColumnToFile($db,$table,$indexColumn,$columnToSelectWithReplace,$orderByColumn,$outputFile);
if ($sqlError) { print "ERROR: sql call falied. $sqlError\n"; die; }



############ Output a selection of columns, each to individual CSV file.
##############################################################################


#### Read from CSV file and parse into ABPersonROWID_FLO hash.  Keys are the ROWID from CSV,  values will be "First Last Organization" from same row.
## %ABPersonROWID_FLO  ABPerson First Last Organization

my %ABPersonROWID_FLO;

## Get ABPerson.First column from First-ABPerson.csv
open (FirstABPersonFH,"<","tableData/First-ABPerson.csv") or die "Could not open [tableData/First-ABPerson.csv]. $!";
while (<FirstABPersonFH>) {
	chomp;
	my ($ROWID,$First) = split /,/,$_,2;
	$First =~ s/\"//g;
	$ABPersonROWID_FLO{$ROWID} = $First;
	#print "$ROWID,$First\n"; 
}
close FirstABPersonFH;

## Get ABPerson.Last column from First-ABPerson.csv
open (LastABPersonFH,"<","tableData/Last-ABPerson.csv") or die "Could not open [tableData/Last-ABPerson.csv]. $!";
while (<LastABPersonFH>) {
	chomp;
	my ($ROWID,$Last) = split /,/,$_,2;
	$Last =~ s/\"//g;
	$ABPersonROWID_FLO{$ROWID} = $ABPersonROWID_FLO{$ROWID} . " " . $Last;
}
close LastABPersonFH;


## Get ABPerson.Organization column from First-ABPerson.csv
open (OrganizationABPersonFH,"<","tableData/Organization-ABPerson.csv") or die "Could not open [tableData/Organization-ABPerson.csv]. $!";
while (<OrganizationABPersonFH>) {
	chomp;
	my ($ROWID,$Organization) = split /,/,$_,2;
	$Organization =~ s/\"//g;
	$ABPersonROWID_FLO{$ROWID} = $ABPersonROWID_FLO{$ROWID} . " " . $Organization;
}
close OrganizationABPersonFH;

## Get ABPersonFullTextSearch_content.c16Phone column into %c16PhoneWithPlus
my %c16PhoneWithPlus;
open (c16PhoneFH,"<","tableData/c16Phone-ABPersonFullTextSearch_content.csv") or die "Could not open [tableData/c6Organization-ABPersonFullTextSearch_content.csv]. $!";
	while (<c16PhoneFH>){
	chomp;
	my ($docid,$c16Phone) = split /,/,$_,2;
	unless ($docid) { die "ERROR: Empty variable [$docid], can't continue.\n" };
	unless ( $c16Phone ) { 
		$c16Phone = "$docid has EMPTYVALUE"; 
	}


## Since ABPersonFullTextSearch_content.c16Phone might contain more than one phone 
## number, search the entire string using space as delimiter.  Use only values that 
## contain more than 10 digits for matching.
	my @c16PhoneStrings = split / /,$c16Phone;
	foreach (@c16PhoneStrings) { 
		next unless $_ =~ /^\+/; ## Only use strings that begin with a +
		next unless $_ =~ /\d{10,}/; ## Match a digit character at least 10 times.
		#print "$_\n";
		$c16PhoneWithPlus{$_} = $docid;
	}
}
close c16PhoneFH;


## Match up ABPersonFullTextSearch_content.c17Email with handle.id and add to c17Email
my %c17Email;  ## email is key docid is value
open (c17EmailFH,"<","tableData/c17Email-ABPersonFullTextSearch_content.csv") or die "Could not open [tableData/c6Organization-ABPersonFullTextSearch_content.csv]. $!";
	while (<c17EmailFH>){
	chomp;
	my ($docid,$c17Email) = split /,/,$_,2;
	unless ($docid) { die "ERROR: Empty variable [$docid], can't continue.\n" };
	$c17Email =~ s/^\"//;
	$c17Email =~ s/\"$//;
	unless ( $c17Email ) { 
		$c17Email = "$docid has EMPTYVALUE"; 
	}

	## c17Email column may contain multiple email addresses, separated by a space
	my @c17Email = split / /, $c17Email;
	
	foreach (@c17Email) {

		$c17Email{$_} = $docid;
	}


}
close c17EmailFH;



#### Get list of all ids listed in handle table.
my @handle_ID;
open (handle_idFH,"<","tableData/id-handle.csv") or die "ERROR Could not open [tableData/id-handle.csv]. $! ";
while (<handle_idFH>) {
	chomp;
	push @handle_ID, $_;
#	my ($ROWID,$id)	= split /,/,$_,2;
# 	$handle_ID{$ROWID}=$id;	
}

close(handle_idFH);


my %handle_rowid_id;
my %handle_id_resolved;

foreach (@handle_ID) {
	chomp;
	next if m/ROWID,id/; ## Skip column titles

	my ($ROWID,$id) = split /,/,$_,2;
	
	if ($ROWID && $id) { $handle_rowid_id{$ROWID} = $id ; }

	## Match handle.id to a name in ABPerson.
	if ( $c16PhoneWithPlus{$id} || $c17Email{$id}) {
		if ($c16PhoneWithPlus{$id}) {
			if ($debugYes) { print "DEBUG: MATCHED phone [$id] to [$c16PhoneWithPlus{$id}] [ $ABPersonROWID_FLO{$c16PhoneWithPlus{$id}}]\n";} 
			$handle_id_resolved{$ROWID} = $ABPersonROWID_FLO{$c16PhoneWithPlus{$id}} ;
		} 
		if ($c17Email{$id}) {
			if ($debugYes) { print "DEBUG: MATCHED email [$id] to [$c17Email{$id}] [ $ABPersonROWID_FLO{$c17Email{$id}}]\n"; }
			$handle_id_resolved{$ROWID} = $ABPersonROWID_FLO{$c17Email{$id}}
		}
	} else {
		#	die "NO MATCH on $ROWID\n";
	}

# 	print "ROWID [$ROWID] id [$id]\n";

}




#### A handle_id of 0 in message table is used to denote SENDING to a group text message AKA chat AKA Conversation.  So we will need to match the column message.cache_roomnames to the chat.chat_identifier column.  Then out to the chat_handle_join column.

#### Get hash of all chat_identifiers.  Value is a string of ROWIDS separated by space.  NOTE: Will need to remove trailing space later when splitting.

my %chat_identifier_allRows;


open (chat_identifierFH,"<","tableData/chat_identifier-chat.csv") or die "ERROR: Could not open [tableData/chat_identifier-chat.csv] for reading. $! ";

while (<chat_identifierFH>) {
	chomp;
	next if (/^ROWID/); ## Used to to skip first line in CSV file.
	my ($ROWID,$chat_identifier) = split /,/,$_,2;

	$chat_identifier_allRows{$ROWID} = $chat_identifier;

}

close(chat_identifierFH);



## Get hash of all chat_handle_join.chat_ids
my %chat_identifier_handle_ids;

## Run through chat_handle_join table and add handle_ids to chat_id

open (handle_id_chat_handle_joinFH,"<","tableData/handle_id-chat_handle_join.csv") or die "ERROR: Could not open [tableData/handle_id-chat_handle_join.csv] for reading. $!";
while (<handle_id_chat_handle_joinFH>) {
	chomp;
	next if (/^chat_id/); ## Used to to skip first line in CSV file.
#	print "$_\n";

	my ($chat_id,$handle_id) = split /,/,$_,2;

	$chat_identifier_handle_ids{$chat_identifier_allRows{$chat_id}} .= "$handle_id ";
#	print "chat_id is [$chat_id] chat_identifier_allRows is [$chat_identifier_allRows{$chat_id}] handle_id is [$handle_id]\n";


}



## Get string of Contacts associated with each chat_identifier
my %chat_identifier_ContactNames;

foreach my $cids_key (keys %chat_identifier_handle_ids){


	my (@listOfhandle_ids) = split / /,$chat_identifier_handle_ids{$cids_key};


	foreach my $idLine (@listOfhandle_ids) {
		my $ContactName = "NONAMEFOUND-chat";
		if ($handle_id_resolved{$idLine}) { $ContactName = $handle_id_resolved{$idLine}; }
		$chat_identifier_ContactNames{$cids_key} .= "($ContactName) ";
	}
}


# foreach my $cicn_key (keys %chat_identifier_ContactNames) {
# 	print "chat_identifier_ContactNames key is [$cicn_key] value is [$chat_identifier_ContactNames{$cicn_key}]\n";
# 	
# }







######## At this point should have everything we need.  Output CSV file with all text messages.

#### Read MESSAGE.txt, parse columns, add handleResolved column output to CSV
my $smsOutputFile = getDeviceNameFromPlist('copiedMsyncBackupFiles/Info.plist') . "-sms.csv";

if (-e $smsOutputFile) { die "ERROR: will not overwrite [$smsOutputFile].\n"; }

## Open CSV file and print column names
open (csvOutputFH,">>","$smsOutputFile") or die "ERROR: Could not open $smsOutputFile";
print csvOutputFH "rowid,timestamp,handle,Contact,Subject,Sent Or Received,Text,\n";


open (messageFH,"<","tableData/MESSAGE.txt") or die "ERROR: Could not open [tableData/MESSAGE.txt]\n";
while (<messageFH>){
	chomp;
	my $chatIDlist=0;
	my $chatHandlesResolved ="null";
	my ($rowid,$timestamp,$is_from_me,$handle_id,$subject,$text,$cache_roomnames) = split /\|/,$_,7;
	my $handleResolved;

	if ( $handle_id_resolved{$handle_id} ) { 
		$handleResolved = $handle_id_resolved{$handle_id};
	} else { 
		$handleResolved = "NONAMEFOUND";
	}


	## If $handle_id = 0 then this is a chat or group message.  Will need to use chat table to determine message recipient(s)
	## relevent columns are message.cache_roomnames and chat.chat_identifier

	if ($handle_id == 0) {

		if ($cache_roomnames =~ m/chat\d+/) {	

			if ($cache_roomnames ne "") {

				$handleResolved = $chat_identifier_ContactNames{$cache_roomnames};
			
			}
		}
	}



	###########################################################################################################################################################			

	my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime($timestamp / 1000000000 + 978307200);
	$year = $year+1900;
	$mon = $mon+1;
	$mon = sprintf("%02d",$mon);
	$mday = sprintf("%02d",$mday);
	$hour = sprintf("%02d",$hour);
	$min = sprintf("%02d",$min);
	$sec = sprintf("%02d",$sec);
	$timestamp = $year.$mon.$mday ."-" . $hour.$min.$sec;

	
	## Escape quotes for CSV compatibility 
	$text =~ s/\"/\"\"/g; 
	$subject =~ s/\"/\"\"/g;
	$handleResolved =~ s/\"/\"\"/g;
	$cache_roomnames =~ s/\"/\"\"/g;

	my $sentOrReceived;
	if ($is_from_me eq 0) { 
		$handle_rowid_id{'0'} = "me";
		$sentOrReceived = "RCV:";
	}

	if ($is_from_me eq 1) { 
		$sentOrReceived = "SNT:";
	}
	
	print csvOutputFH "$rowid,$timestamp,\"$handle_rowid_id{$handle_id}\",\"$handleResolved\",\"$subject\",$sentOrReceived,\"$text\"\n";

}


close messageFH;
close csvOutputFH;

system("open ./");
 
print " -----------------------------------------------------------\n";
print "| Completed $thisScript at " . localtime . "\n";
print " -----------------------------------------------------------\n";








##############################################################################
#### Subroutines

sub getDeviceNameFromPlist {
	my $plistFile = $_[0];
	my $Device_Name = "null";

	unless (-r "$plistFile") {
		return "No Plist found or could not read [$plistFile]";
	}

	open (plistFH, "<", $plistFile);

	my $loopFlag;
	my $plistLine;

	while (<plistFH>) {
		$plistLine = $_;
		chomp $plistLine;

		if ($loopFlag) {
			$Device_Name = $plistLine;
			last;
		}

		if ($plistLine =~ m/<key>Device Name<\/key>/) { 
			$loopFlag = 1; 
		}
	}

	close plistFH;

	$Device_Name =~ s/.*<string>//s;
	$Device_Name =~ s/<\/string>.*//s;

	return $Device_Name;

}



sub outputColumnToFile {
	my $dbName; ## sqlDB file. i.e. 3d0d7e5fb2ce288813306e4d4636395e047a3d28
	my $tableName; ## table we will get column from i.e. message
	my $indexColumn; ## IMPORTANT must chose name of column considered to be the row index i.e. ROWID
	my $columnSelect;  ## i.e. handle_id OR replace function such as replace(REPLACE(text, '\r', '<crNEWLINE>'), '\n', '<nNEWLINE>') i.e. text
	my $orderByColumn; ## Column to sort by i.e. ROWID
	my $outputFile;  ## textFile that we will output to. i.e. message.text.txt

	$dbName = $_[0];
	$tableName = $_[1]; 
	$indexColumn = $_[2]; 
	$columnSelect = $_[3];
	$orderByColumn = $_[4]; 
	$outputFile = $_[5];  


	unless ( (scalar @_) == 6) {die "ERROR: not enough arguments to outputColumnToTxt.  Missing one or more of dbName,tableName,indexColumn,columnSelect,orderByColumn,outputFile.  Need 6, only got " . scalar @_ . ". $!"; }


	## Do not overwrite files
	if (-e $outputFile) { die "ERROR: Will not overwrite [$outputFile]. $!"; }


	## Output CSV header.
	open (outputFH, ">>",$outputFile) or die "Could not open output file [$outputFile] $!"; ## AAA remember to switch this back to >>
	print outputFH "$indexColumn,$columnSelect\n";
	close outputFH;
	my $sqlCall = "sqlite3 -csv $dbName \"select $indexColumn,$columnSelect from $tableName order by $orderByColumn\" >> $outputFile"; 

	## Make sure we can read DB file
	unless (-r $dbName) {die "Could not read [$dbName] $!"; }

	## Execute sql
#	my $sqlError;
#	system ("$sqlCall") == 0 or die "sqlCall [$sqlCall] failed. $!";
	system ("$sqlCall") == 0 or return "sqlCall was [$sqlCall] failed.";
#	if ($!) { $sqlError = $!;}
	if ($debugYes) { print "DEBUG: sql call was [$sqlCall].\n"; }
	
	return 0;
	
	#$sqlError = 1000;

#	if ($sqlError) {return $sqlError;}
}




sub copyFileUsingOpen {
	## copyFileUsingOpen.  Avoiding system, backticks or Perl Modules for now.

	my $copyFromDir = $_[0]; ## Directory where file to copy resides
	my $copyFromName = $_[1]; ## Name of file to copy
	my $copyToDir = $_[2];  ## Directory where copied file will be output
	my $copyToName = $_[3];  ## Name of outputfile (prob same as copyFromName)

	unless ($copyFromDir) { die "$! \nERROR: copyFromDir is required.\n";}
	unless ($copyFromName) { die "$! \nERROR: copyFromName is required.\n";}
	unless ($copyToDir) { die "$! \nERROR: copyToDir is required.\n";}
	unless ($copyToName) { die "$! \nERROR: copyToName is required.\n";}
	
	unless (-r "$copyFromDir/$copyFromName") { die $! . "ERROR: [$copyFromDir/$copyFromName] is not readable.\n" }
	unless (-d $copyToDir && -w $copyToDir) { die "ERROR: [$copyToDir] is not a directory or is not writeable.\n$!" }
	if (-e "$copyToDir/$copyToDir") { die "ERROR: File exists, will not overwrite [$copyFromDir/$copyFromName].\n$!" }
	
	## Get mod time of file to copy
	my ($dev,$ino,$mode,$nlink,$uid,$gid,$rdev,$size,$atime,$mtime,$ctime,$blksize,$blocks) = stat("$copyFromDir/$copyFromName");
	my $fromMtime = $mtime;
	my $fromSize = $size;
	#print $mtime;
	
	## Open input file
	open (inputFH,"<","$copyFromDir/$copyFromName") or die "$! \nERROR: Could not read [$copyFromDir/$copyFromName].\n";
	
	## open output file
	open (outputFH,">>","$copyToDir/$copyToName") or  die "$! \nERROR: Could not open for writing [$copyToDir/$copyToName].\n";
	
	## Copy the file.  Read input from file being copied and print to output file.
	while (<inputFH>) {
		print outputFH;
	}

	close inputFH;
	close outputFH;


	## Modify mod timestamp of file we copied to match original
	utime $mtime, $mtime, "$copyToDir/$copyToName";


	## compare size of copied file to original
	($dev,$ino,$mode,$nlink,$uid,$gid,$rdev,$size,$atime,$mtime,$ctime,$blksize,$blocks) = stat("$copyFromDir/$copyFromName");
	my $toMtime = $mtime;
	my $toSize = $size;
	unless ($fromSize == $toSize) { die "ERROR: Copied file size does not match original. [$copyToDir/$copyToName]\n"}
	
}


#### Subroutines
##############################################################################



