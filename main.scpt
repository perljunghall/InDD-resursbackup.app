property myVersion : "1.0.2"
property myCoprightNotice : "© 2017, Per Ljunghall, HD-Sydsvenskan, All Rights Reserved."

----------------------------------------------------------------------------
--» Changelog
-- 1.0.2 sets version (myVersion) and copyrights notice (myCoprightNotice) in info.plist, visible in Finder info panel.


----------------------------------------------------------------------------
--» Configuration
----------------------------------------------------------------------------

(*
Configuration is done in plist file thePlistPath (definied below).
"Default values" are set in code only to set values when missing in plist, ie when plist is missing like on first run.
- If plist file exists it will be read. Finns det en plist-fil kommer den att läsas. 
- If one or more values are missing in plist they will be set from above mentioned default values.

plist file is read at the beginning of every backup cycle = no need for restart of app to make changes in plist.
*)

-- Default values, populate plist when plist is missing:
-- Log level, INFO, WARNING or ERROR. INFO includes WARNING and ERROR, WARNING includes ERROR:
property default_theLogLevel_INFO_WARNING_ERROR : "WARNING"

-- Target folder, parent of all backups:
property default_theTargetFolder : "/Volumes/redaktionm/Backup/InD-links/"

-- Volumes from which the app will try to copy files:
-- NOTE! Must be only volume name, not part of path. All slashes will be removed by code.
property default_theValidVolumes : {"annonsm", "Bilder", "Bilder2", "pdfout", "redaktionm"}

-- Time in minutes from end of backup cycle to beginning of next:
property default_theBackupIntervalInMinutes : 30

-- Number of days ahead pages will be backed
property default_theDaysForward : 3

-- Age of backup folders before deleting.
-- "1" deletes folders 1 day old, i.e. _older_ than "today".
-- "0" deletes folders of "today", i.e. delete "today" and older.
-- NOTE: the day lasts theMinutesAfterMidnightNewDayBegins minutes into the next day.
property default_theDaysToKeepOldBackups : 2

-- Minutes after midnight today turns to tomorrow, relevant only in deciding how old backups you want to keep.
-- With value "60" January 1 lasts from Jan 1, 01:00:00 to Jan 2, 00:59:59.
-- NOTE: Negative value moves day shift to before midnight.
property default_theMinutesAfterMidnightNewDayBegins : 60

-- Folders to look for date folders in:
property default_theSourceFolders : {"/Volumes/redaktionm/Pilot/sidor/", "/Volumes/redaktionm/Pilot/sidor_halla/"}

----------------------------------------------------------------------------
-- THESE VALUES ARE NOT CHANGEABLE IN PLIST FILE:
-- Log and plist settings:
-- Name of the log file, excluding suffix:
property myScriptNameToLog : "InDD-resursbackup"

-- Posix path to plist file. Must not be quoted, special characters must be escaped:
property thePlistPath : "~/Library/Preferences/HD-Sydsvenskan/InDD-resursbackup.plist"


--/ Configuration
----------------------------------------------------------------------------

property theLogLevel_INFO_WARNING_ERROR : null
global theTargetFolder, theBackupIntervalInMinutes, theSourceFolders, theDaysForward, theDaysToKeepOldBackups, theMinutesAfterMidnightNewDayBegins, theValidVolumes
global thePathToExifTool, g_theLog, myLoggerFile, theSourceFolders, endTime, theRsyncCount_success, theRsyncCount_fail

----------------------------------------------------------------------------

on run
	if theLogLevel_INFO_WARNING_ERROR is null then set theLogLevel_INFO_WARNING_ERROR to default_theLogLevel_INFO_WARNING_ERROR
	set AppleScript's text item delimiters to ""
	set g_theLog to {}
	set {myPathToMe, myScriptFolderPath, myLoggerFile} to my doGetNamesAndPaths()
	my doSetPlistValues(myPathToMe)
	(my doWriteToLog(myLoggerFile, myScriptNameToLog, myVersion, "----------------------------------------------------------------------------------------------------", ""))
	(my doWriteToLog(myLoggerFile, myScriptNameToLog, myVersion, "INFO", "Run..."))
	set thePathToExifTool to (POSIX path of (path to resource "ExifTool")) as Unicode text
	set endTime to date "torsdag 1 januari 1970 00:00:00"
	my getDefaults()
	idle
end run

on idle
	set TT to (current date)
	(my doWriteToLog(myLoggerFile, myScriptNameToLog, myVersion, "INFO", "Begin cycle"))
	set {theRsyncCount_success, theRsyncCount_fail, theInDDCount} to {"N/A", "N/A", "N/A"}
	
	if (endTime + 59) < (current date) then
		set {theRsyncCount_success, theRsyncCount_fail, theInDDCount} to {0, 0, 0}
		my getDefaults()
		set myList to {}
		try
			repeat with I from 1 to (count theSourceFolders)
				set myFolder to item I of theSourceFolders
				try
					set theDateFolders to (my doGetCurrentFolders(myFolder))
					repeat with II from 1 to count theDateFolders
						set myCurrentFolder to item II of theDateFolders
						try
							set theFiles to paragraphs of (do shell script "ls " & myCurrentFolder)
							repeat with III from 1 to (count theFiles)
								set myFile to item III of theFiles
								if myFile ends with ".indd" then
									try
										if theLogLevel_INFO_WARNING_ERROR is in {"INFO"} then (my doWriteToLog(myLoggerFile, myScriptNameToLog, myVersion, "INFO", ("Examining " & myFile)))
										set theFiles_backup to my doGetFilesUsedInINDD({myCurrentFolder, myFile})
										-- Backup
										get theFiles_backup
										my doBackup({myCurrentFolder, theFiles_backup})
										set theInDDCount to theInDDCount + 1
									on error err number errNum
										(my doWriteToLog(myLoggerFile, myScriptNameToLog, myVersion, "ERROR", "errNum " & errNum & ", " & err))
									end try
									-- DEBUG:
									-- else
									-- get myFile
								end if
							end repeat
						on error err number errNum
							(my doWriteToLog(myLoggerFile, myScriptNameToLog, myVersion, "ERROR", "errNum " & errNum & ", " & err))
						end try
					end repeat
				on error err number errNum
					(my doWriteToLog(myLoggerFile, myScriptNameToLog, myVersion, "ERROR", "errNum " & errNum & ", " & err))
				end try
			end repeat
		on error err number errNum
			(my doWriteToLog(myLoggerFile, myScriptNameToLog, myVersion, "ERROR", "errNum " & errNum & ", " & err))
		end try
		my doDeleteOldBackups()
		set endTime to (current date)
	end if
	my doWriteToLog(myLoggerFile, myScriptNameToLog, myVersion, "INFO", "End cycle after " & (get (my FormatSeconds(((current date) - TT)))) & " (HH:MM:SS), " & theInDDCount & " InDD, rsync success: " & theRsyncCount_success & " files, rsync fail: " & theRsyncCount_fail & " files")
	return (theBackupIntervalInMinutes * minutes)
end idle


on quit
	(my doWriteToLog(myLoggerFile, myScriptNameToLog, myVersion, "INFO", "Quit"))
	continue quit
end quit


----------------------------------------------------------------------------
----------------------------------------------------------------------------

on FormatSeconds(totalSeconds)
	set theHours to (totalSeconds div hours)
	set theRemainderSeconds to (totalSeconds mod hours)
	set theMinutes to (theRemainderSeconds div minutes)
	set theRemainderSeconds to (theRemainderSeconds mod minutes)
	if length of (theHours as text) = 1 then set theHours to "0" & (theHours as text)
	if length of (theMinutes as text) = 1 then set theMinutes to "0" & (theMinutes as text)
	if length of (theRemainderSeconds as text) = 1 then set theRemainderSeconds to "0" & (theRemainderSeconds as text)
	set theTimeString to theHours & ":" & theMinutes & ":" & theRemainderSeconds as text
	return theTimeString
end FormatSeconds

on doDeleteOldBackups()
	if theLogLevel_INFO_WARNING_ERROR is in {"INFO"} then (my doWriteToLog(myLoggerFile, myScriptNameToLog, myVersion, "INFO", "Begin old backup delete subroutine \"doDeleteOldBackups()\""))
	
	set theAllParentFolders to paragraphs of (do shell script "ls -F " & quoted form of theTargetFolder)
	repeat with myParentFolder in theAllParentFolders
		set theFolders to paragraphs of (do shell script "ls -F " & quoted form of (theTargetFolder & (contents of myParentFolder)))
		set theDeleteFolders to {}
		
		-- If date in foldername is older than today - 1 day then delete folder using "rm -rf *":
		repeat with I from 1 to (count theFolders)
			set myFolder to item I of theFolders
			set AppleScript's text item delimiters to "-"
			set theFolderDate to ({text -7 thru -6, text -5 thru -4, text -3 thru -2} of myFolder)
			set theFolderDate to ("20" & (theFolderDate as Unicode text))
			set AppleScript's text item delimiters to ""
			set theToday to short date string of (current date)
			try
				if date theFolderDate ≤ ((date (short date string of ((current date) - theMinutesAfterMidnightNewDayBegins * minutes))) - theDaysToKeepOldBackups * days) then
					set theShellScript to "rm -rf " & quoted form of (theTargetFolder & (contents of myParentFolder & myFolder))
					my doShellScript(theShellScript, "ERROR")
				end if
			on error err number errNum
				if theLogLevel_INFO_WARNING_ERROR is in {"INFO", "WARNING"} then (my doWriteToLog(myLoggerFile, myScriptNameToLog, myVersion, "WARNING", ("errNum " & errNum & ", " & err & ", " & (contents of myParentFolder) & myFolder)))
			end try
		end repeat
	end repeat
end doDeleteOldBackups

on doShellScript(theShellScript, theFailState)
	try
		set R to do shell script theShellScript
		if theLogLevel_INFO_WARNING_ERROR is in {"INFO"} then (my doWriteToLog(myLoggerFile, myScriptNameToLog, myVersion, "INFO", theShellScript))
		return R
	on error err number errNum
		if theLogLevel_INFO_WARNING_ERROR is in {"ERROR"} and theFailState is in {"ERROR"} then
			(my doWriteToLog(myLoggerFile, myScriptNameToLog, myVersion, theFailState, (theShellScript & tab & ("errNum " & errNum & ", " & err))))
		else if theLogLevel_INFO_WARNING_ERROR is in {"WARNING"} and theFailState is in {"WARNING", "ERROR"} then
			(my doWriteToLog(myLoggerFile, myScriptNameToLog, myVersion, theFailState, (theShellScript & tab & ("errNum " & errNum & ", " & err))))
		else if theLogLevel_INFO_WARNING_ERROR is in {"INFO"} then
			(my doWriteToLog(myLoggerFile, myScriptNameToLog, myVersion, theFailState, (theShellScript & tab & ("errNum " & errNum & ", " & err))))
		end if
		return err
	end try
end doShellScript

on doBackup(myList)
	get myList
	
	if theLogLevel_INFO_WARNING_ERROR is in {"INFO"} then (my doWriteToLog(myLoggerFile, myScriptNameToLog, myVersion, "INFO", "Begin backup subroutine \"doBackup(myList)\""))
	
	set mySourceFolder to item 1 of myList
	set AppleScript's text item delimiters to "/"
	
	if character -1 of mySourceFolder is "/" then
		set theProduct to text item -3 of mySourceFolder
		set theInDDParent to text item -2 of mySourceFolder
	else
		set theProduct to text item -2 of mySourceFolder
		set theInDDParent to text item -1 of mySourceFolder
	end if
	set theInDDName to item 1 of item 2 of myList
	set theInDDResources to item 2 of item 2 of myList
	if theLogLevel_INFO_WARNING_ERROR is in {"INFO"} then (my doWriteToLog(myLoggerFile, myScriptNameToLog, myVersion, "INFO", theInDDResources))
	
	set AppleScript's text item delimiters to ", file://"
	set theInDDResources to text items of theInDDResources
	set theShellScript to "mkdir -p " & quoted form of (theTargetFolder & "/" & theProduct & "/" & theInDDParent & "/" & theInDDName)
	my doShellScript(theShellScript, "ERROR")
	
	-- empty list for storing what has been copied
	set theDone to {}
	repeat with theItem_InDDResource in theInDDResources
		try
			if theItem_InDDResource begins with "file://" then set theItem_InDDResource to text 8 thru -1 of theItem_InDDResource
			-- Convert url to posix path:
			set theItem_InDDResource to do shell script "python -c 'import sys, urllib; print urllib.unquote(sys.argv[1])' " & quoted form of theItem_InDDResource
			set AppleScript's text item delimiters to "/"
			set theInDRName to text item -1 of theItem_InDDResource
			set {thePath1, thePath2} to {text item 2, text item 3} of theItem_InDDResource
			set AppleScript's text item delimiters to ""
			
			if thePath1 is "Volumes" and thePath2 is in theValidVolumes then
				-- if resource is copied it is stored in theDone and will not be copied again
				if theItem_InDDResource is not in theDone then
					set theShellScript to "rsync " & (quoted form of theItem_InDDResource) & " " & quoted form of (theTargetFolder & theProduct & "/" & theInDDParent & "/" & theInDDName & "/")
					set theReturn to (my doShellScript(theShellScript, "ERROR"))
					-- Store resource in theDone when copied
					if theReturn is "" then
						set theRsyncCount_success to theRsyncCount_success + 1
						set end of theDone to theItem_InDDResource
					else
						set theRsyncCount_fail to theRsyncCount_fail + 1
						(my doWriteToLog(myLoggerFile, myScriptNameToLog, myVersion, "ERROR", (theInDDName & ".indd" & tab & theReturn)))
					end if
				end if
			else
				if theLogLevel_INFO_WARNING_ERROR is in {"INFO"} then (my doWriteToLog(myLoggerFile, myScriptNameToLog, myVersion, "INFO", "Invalid file path: " & theItem_InDDResource))
			end if
		on error err number errNum
			(my doWriteToLog(myLoggerFile, myScriptNameToLog, myVersion, "ERROR", (theInDDName & ".indd" & tab & "errNum " & errNum & ", " & err)))
		end try
	end repeat
end doBackup


-- Ta ut inlänkade filer ur InDD med ExifTool
-- Get links from InDD with "exiftool -IngredientsFilePath -s3 *"
on doGetFilesUsedInINDD({myFolder, myFile})
	try
		-- Get path to InDD:
		set myFilePath to POSIX path of (myFolder & myFile)
		-- Get filename without suffix to use for naming of backup folder:
		set AppleScript's text item delimiters to "."
		try
			set myFile to ((text items 1 thru -2 of myFile) as Unicode text)
		on error err number errNum
			if theLogLevel_INFO_WARNING_ERROR is in {"INFO", "WARNING"} then (my doWriteToLog(myLoggerFile, myScriptNameToLog, myVersion, "WARNING", ("Can't get name without suffix: " & myFilePath), "errNum " & errNum & ", " & err))
		end try
		set AppleScript's text item delimiters to ""
		-- Entire path to ExifTool must be defined when run from within applescript app:
		set theShellScript to (quoted form of (thePathToExifTool & "exiftool") & " -IngredientsFilePath -s3 " & quoted form of myFilePath)
		set myExif to my doShellScript(theShellScript, "ERROR")
		return {myFile, myExif}
	on error err number errNum
		(my doWriteToLog(myLoggerFile, myScriptNameToLog, myVersion, "ERROR", "errNum " & errNum & ", " & err))
		return {}
	end try
end doGetFilesUsedInINDD


global tmp, theShortDate, D, theReturn, theItem
-- identify current datefolders:
on doGetCurrentFolders(F)
	set D to {}
	-- ls, directory inventory, -F adds "/" at end of directory names
	set tmp to paragraphs of (do shell script ("ls -F " & quoted form of F))
	-- Get dated dirs from tomorrow and theDaysForward number of days:
	repeat with I from 1 to theDaysForward
		-- convert date from yyyy-MM-dd to yyMMdd
		set theShortDate to ({text 3 thru 4, text 6 thru 7, text 9 thru 10} of (short date string of (((current date) - (theMinutesAfterMidnightNewDayBegins * minutes)) + I * days)))
		-- add trailing slash to match (end of) folder name previously generated by "ls -F "
		set end of D to (theShortDate & "/") as Unicode text
	end repeat
	
	set theReturn to {}
	repeat with theItem in tmp
		try
			-- text -7 thru -1 = "yyMMdd/"
			if text -7 thru -1 of theItem is in D then set end of theReturn to (F & theItem) as Unicode text
		on error err number errNum
			if theLogLevel_INFO_WARNING_ERROR is in {"INFO", "WARNING"} then (my doWriteToLog(myLoggerFile, myScriptNameToLog, myVersion, "WARNING", ("Can't get date from folder " & (F & contents of theItem)), "errNum " & errNum & ", " & err))
		end try
	end repeat
	return theReturn
end doGetCurrentFolders



-- Make, read and write plist
on getDefaults()
	-- Create dir for plist if missing
	set AppleScript's text item delimiters to "/"
	set tmp to text items 1 thru -2 of thePlistPath
	set tmp to tmp as Unicode text
	set AppleScript's text item delimiters to ""
	set theShellScript to ("mkdir -p " & tmp)
	my doShellScript(theShellScript, "ERROR")
	
	(*
-- add new property list items of each of the supported types
{kind:boolean, name:"booleanKey", value:true}
{kind:date, name:"dateKey", value:current date}
{kind:list, name:"listKey", value:{1, "A", {2, "B", "C"}}}
{kind:integer, name:"integerKey", value:20}
{kind:real, name:"realKey", value:21.5}
{kind:record, name:"recordKey", value:{1, "A", {2, "B", "C"}}}
{kind:string, name:"stringKey", value:"string value"}
	
-- set thewrite to (my doWritePlist(thePlistPath, "theKeyName", integer, 10))
-- set theread to (my doReadPlist(thePlistPath, "theKeyName"))
*)
	
	-- Read plist value
	set theLogLevel_INFO_WARNING_ERROR to (my doReadPlist(thePlistPath, "theLogLevel_INFO_WARNING_ERROR"))
	if theLogLevel_INFO_WARNING_ERROR is null then
		-- Write default value if plist lacks needed value
		set theLogLevel_INFO_WARNING_ERROR to (my doWritePlist(thePlistPath, "theLogLevel_INFO_WARNING_ERROR", string, default_theLogLevel_INFO_WARNING_ERROR))
		if theLogLevel_INFO_WARNING_ERROR is in {"INFO"} then (my doWriteToLog(myLoggerFile, myScriptNameToLog, myVersion, "INFO", "plist, set theLogLevel_INFO_WARNING_ERROR: " & default_theLogLevel_INFO_WARNING_ERROR))
		-- Read plist value
		set theLogLevel_INFO_WARNING_ERROR to (my doReadPlist(thePlistPath, "theLogLevel_INFO_WARNING_ERROR"))
	else
		if theLogLevel_INFO_WARNING_ERROR is in {"INFO"} then (my doWriteToLog(myLoggerFile, myScriptNameToLog, myVersion, "INFO", "plist, read theLogLevel_INFO_WARNING_ERROR: " & theLogLevel_INFO_WARNING_ERROR))
	end if
	
	set theTargetFolder to (my doReadPlist(thePlistPath, "theTargetFolder"))
	if theTargetFolder is null then
		-- Write default value if plist lacks needed value
		set theTargetFolder to (my doWritePlist(thePlistPath, "theTargetFolder", string, default_theTargetFolder))
		if theLogLevel_INFO_WARNING_ERROR is in {"INFO"} then (my doWriteToLog(myLoggerFile, myScriptNameToLog, myVersion, "INFO", "plist, set theTargetFolder: " & default_theTargetFolder))
		-- Read plist value
		set theTargetFolder to (my doReadPlist(thePlistPath, "theTargetFolder"))
	else
		if theLogLevel_INFO_WARNING_ERROR is in {"INFO"} then (my doWriteToLog(myLoggerFile, myScriptNameToLog, myVersion, "INFO", "plist, read theTargetFolder: " & theTargetFolder))
	end if
	-- Add trailing slash if missing:
	if character -1 of theTargetFolder is not "/" then set theTargetFolder to (theTargetFolder & "/")
	
	set theValidVolumes to (my doReadPlist(thePlistPath, "theValidVolumes"))
	if theValidVolumes is null then
		-- Write default value if plist lacks needed value
		set theValidVolumes to (my doWritePlist(thePlistPath, "theValidVolumes", list, default_theValidVolumes))
		if theLogLevel_INFO_WARNING_ERROR is in {"INFO"} then (my doWriteToLog(myLoggerFile, myScriptNameToLog, myVersion, "INFO", "plist, set default_theValidVolumes: " & default_theValidVolumes))
		-- Read plist value
		set theValidVolumes to (my doReadPlist(thePlistPath, "theValidVolumes"))
	else
		if theLogLevel_INFO_WARNING_ERROR is in {"INFO"} then (my doWriteToLog(myLoggerFile, myScriptNameToLog, myVersion, "INFO", "plist, read theValidVolumes: " & theValidVolumes))
	end if
	-- remove surrounding slashes if existing:
	set tmp to {}
	repeat with theItem in theValidVolumes
		set AppleScript's text item delimiters to "/"
		set tmp_1 to text items of theItem
		set AppleScript's text item delimiters to ""
		set end of tmp to tmp_1 as Unicode text
	end repeat
	set theValidVolumes to tmp
	
	set theBackupIntervalInMinutes to (my doReadPlist(thePlistPath, "theBackupIntervalInMinutes"))
	if theBackupIntervalInMinutes is null then
		set theBackupIntervalInMinutes to (my doWritePlist(thePlistPath, "theBackupIntervalInMinutes", integer, default_theBackupIntervalInMinutes))
		if theLogLevel_INFO_WARNING_ERROR is in {"INFO"} then (my doWriteToLog(myLoggerFile, myScriptNameToLog, myVersion, "INFO", "plist, set theBackupIntervalInMinutes: " & default_theBackupIntervalInMinutes))
		set theBackupIntervalInMinutes to (my doReadPlist(thePlistPath, "theBackupIntervalInMinutes"))
	else
		if theLogLevel_INFO_WARNING_ERROR is in {"INFO"} then (my doWriteToLog(myLoggerFile, myScriptNameToLog, myVersion, "INFO", "plist, read theBackupIntervalInMinutes: " & theBackupIntervalInMinutes))
	end if
	
	set theMinutesAfterMidnightNewDayBegins to (my doReadPlist(thePlistPath, "theMinutesAfterMidnightNewDayBegins"))
	if theMinutesAfterMidnightNewDayBegins is null then
		set theMinutesAfterMidnightNewDayBegins to (my doWritePlist(thePlistPath, "theMinutesAfterMidnightNewDayBegins", integer, default_theMinutesAfterMidnightNewDayBegins))
		if theLogLevel_INFO_WARNING_ERROR is in {"INFO"} then (my doWriteToLog(myLoggerFile, myScriptNameToLog, myVersion, "INFO", "plist, set theBackupIntervalInMinutes: " & default_theMinutesAfterMidnightNewDayBegins))
		set theMinutesAfterMidnightNewDayBegins to (my doReadPlist(thePlistPath, "theMinutesAfterMidnightNewDayBegins"))
	else
		if theLogLevel_INFO_WARNING_ERROR is in {"INFO"} then (my doWriteToLog(myLoggerFile, myScriptNameToLog, myVersion, "INFO", "plist, read theMinutesAfterMidnightNewDayBegins: " & theMinutesAfterMidnightNewDayBegins))
	end if
	
	set theDaysForward to (my doReadPlist(thePlistPath, "theDaysForward"))
	if theDaysForward is null then
		set theDaysForward to (my doWritePlist(thePlistPath, "theDaysForward", integer, default_theDaysForward))
		if theLogLevel_INFO_WARNING_ERROR is in {"INFO"} then (my doWriteToLog(myLoggerFile, myScriptNameToLog, myVersion, "INFO", "plist, set theDaysForward: " & default_theDaysForward))
		set theDaysForward to (my doReadPlist(thePlistPath, "theDaysForward"))
	else
		if theLogLevel_INFO_WARNING_ERROR is in {"INFO"} then (my doWriteToLog(myLoggerFile, myScriptNameToLog, myVersion, "INFO", "plist, read theDaysForward: " & theDaysForward))
	end if
	
	set theDaysToKeepOldBackups to (my doReadPlist(thePlistPath, "theDaysToKeepOldBackups"))
	if theDaysToKeepOldBackups is null then
		set theDaysToKeepOldBackups to (my doWritePlist(thePlistPath, "theDaysToKeepOldBackups", integer, default_theDaysToKeepOldBackups))
		if theLogLevel_INFO_WARNING_ERROR is in {"INFO"} then (my doWriteToLog(myLoggerFile, myScriptNameToLog, myVersion, "INFO", "plist, set theDaysToKeepOldBackups: " & default_theDaysToKeepOldBackups))
		set theDaysToKeepOldBackups to (my doReadPlist(thePlistPath, "theDaysToKeepOldBackups"))
	else
		if theLogLevel_INFO_WARNING_ERROR is in {"INFO"} then (my doWriteToLog(myLoggerFile, myScriptNameToLog, myVersion, "INFO", "plist, read theDaysToKeepOldBackups: " & theDaysToKeepOldBackups))
	end if
	
	set theSourceFolders to (my doReadPlist(thePlistPath, "theSourceFolders"))
	set AppleScript's text item delimiters to ", "
	if theSourceFolders is null then
		set theSourceFolders to (my doWritePlist(thePlistPath, "theSourceFolders", list, default_theSourceFolders))
		if theLogLevel_INFO_WARNING_ERROR is in {"INFO"} then (my doWriteToLog(myLoggerFile, myScriptNameToLog, myVersion, "INFO", "plist, set theSourceFolders: " & (default_theSourceFolders as Unicode text)))
		set theSourceFolders to (my doReadPlist(thePlistPath, "theSourceFolders"))
	else
		if theLogLevel_INFO_WARNING_ERROR is in {"INFO"} then (my doWriteToLog(myLoggerFile, myScriptNameToLog, myVersion, "INFO", "plist, read theSourceFolders: " & (theSourceFolders as Unicode text)))
	end if
	set AppleScript's text item delimiters to ""
	-- Add trailing slashes if missing:
	set tmp to {}
	repeat with theItem in theSourceFolders
		if character -1 of (contents of theItem) is "/" then
			set end of tmp to (contents of theItem)
		else
			set end of tmp to (contents of theItem) & "/"
		end if
	end repeat
	set theSourceFolders to tmp
	
end getDefaults

on doGetNamesAndPaths()
	-- Path to app:
	set myPathToMe to (path to me as Unicode text)
	set AppleScript's text item delimiters to ""
	-- path to bundled scripts folder
	set myScriptFolderPath to (path to resource "Scripts") as Unicode text
	-- path to script that writes to log file
	set myLoggerFile to (myScriptFolderPath & "write_to_log.scpt") as Unicode text
	return {myPathToMe, myScriptFolderPath, myLoggerFile}
end doGetNamesAndPaths

------------------------------------------------------------------------------------------
--» Plist handling

on doSetPlistValues(myPathToMe)
	try
		(my doWritePlist((myPathToMe & "Contents:Info.plist"), "CFBundleShortVersionString", string, myVersion))
	on error err number errNum
		get err
	end try
	try
		(my doWritePlist((myPathToMe & "Contents:Info.plist"), "NSHumanReadableCopyright", string, myCoprightNotice))
	on error err number errNum
		get err
	end try
end doSetPlistValues

on doReadPlist(thePlistPath, theKeyName)
	tell application "System Events"
		try
			set this_plistfile to property list file thePlistPath
		on error
			set this_plistfile to my doMakePlistFile(thePlistPath)
		end try
		try
			return value of property list item theKeyName of contents of this_plistfile
		on error
			return null
		end try
	end tell
end doReadPlist

on doWritePlist(thePlistPath, theKeyName, theKeyKind, theKeyValue)
	tell application "System Events"
		try
			set this_plistfile to property list file thePlistPath
		on error
			set this_plistfile to my doMakePlistFile(thePlistPath)
		end try
		try
			try
				set value of property list item theKeyName of contents of this_plistfile to theKeyValue
			on error
				make new property list item at end of property list items of contents of this_plistfile ¬
					with properties {kind:theKeyKind, name:theKeyName, value:theKeyValue}
			end try
			return true
		on error err number errNum
			return err
		end try
	end tell
end doWritePlist

on doMakePlistFile(thePlistPath)
	tell application "System Events"
		try
			set the parent_dictionary to make new property list item with properties {kind:record}
			set this_plistfile to make new property list file with properties {contents:parent_dictionary, name:thePlistPath}
			return this_plistfile
		on error err number errNum
			return err
		end try
	end tell
end doMakePlistFile

--/ Plist handling
------------------------------------------------------------------------------------------

on doWriteToLog(myLoggerFile, myAppName, myVersion, theState, theMessage)
	ignoring application responses
		try
			set theLogReturn to run script alias myLoggerFile with parameters {myAppName, myVersion, theState, theMessage}
		end try
	end ignoring
end doWriteToLog
