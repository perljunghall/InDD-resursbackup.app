property theNumberOfLogsToKeep : 10
property theMaximumLogFileSizeInBytes : 5000000

on run argv
	set {myDateString, myTimeString} to {short date string, time string} of (current date)
	try
		set myIP to do shell script "ifconfig | grep 'broadcast' | awk '{print $2}'"
		set myIP to paragraph 1 of myIP
	on error
		set myIP to "[IP missing]"
	end try
	set myLogFolder to ((path to home folder as string) & "Library:Logs:HD-Sydsvenskan:")
	try
		set myScriptNameToLog to (item 1 of argv)
	on error
		set myScriptNameToLog to "RunBundledScripts"
	end try
	
	tell me to set text item delimiters to tab
	try
		set myEntry to (text items 2 thru -1 of argv as string)
	on error err
		set myEntry to err
	end try
	set myLog to {myDateString, myTimeString, myIP, myEntry} as string
	tell me to set text item delimiters to ""
	
	my doWriteToLog(myLog, myLogFolder, (myLogFolder & myScriptNameToLog & ".log"))
	
end run

-----------------------------------------
--» HANDLERS
-----------------------------------------

-- Write to logfile
on doWriteToLog(myLog, myLogFolder, myLogFile)
	my doShellScript(("mkdir -p " & quoted form of POSIX path of myLogFolder))
	if ((my doGetFileSize(myLogFile)) as number) > theMaximumLogFileSizeInBytes then (my doMakeNewLogFile(myLogFile))
	my doShellScript(("touch " & quoted form of POSIX path of myLogFile))
	try
		close access file myLogFile
	end try
	-- Write:
	try
		set fileRef to (open for access myLogFile with write permission)
		write myLog & return to fileRef starting at eof as «class utf8»
		close access fileRef
	on error err
		display dialog err
	end try
end doWriteToLog

-- Rotate logfile
on doMakeNewLogFile(myLogFile)
	get myLogFile
	try
		do shell script "ls " & quoted form of POSIX path of ((myLogFile & "." & theNumberOfLogsToKeep) as string)
		do shell script "rm " & quoted form of POSIX path of ((myLogFile & "." & theNumberOfLogsToKeep) as string)
	end try
	repeat with I from (theNumberOfLogsToKeep - 1) to 1 by -1
		try
			do shell script "mv " & quoted form of POSIX path of (myLogFile & "." & (I as string)) & " " & quoted form of POSIX path of (myLogFile & "." & ((I + 1) as string))
		end try
	end repeat
	do shell script "mv " & quoted form of POSIX path of myLogFile & " " & quoted form of POSIX path of ((myLogFile & ".1") as string)
end doMakeNewLogFile

-- Check size of logfile
on doGetFileSize(theInput)
	if theInput contains ":" then set theInput to POSIX path of theInput
	do shell script ("touch " & quoted form of POSIX path of theInput)
	return (do shell script "stat -f '%z' " & quoted form of POSIX path of theInput)
end doGetFileSize

-- Execute
on doShellScript(theCurrentScript)
	try
		return {true, do shell script theCurrentScript}
	on error err
		return {false, err}
	end try
end doShellScript

