; #pragma compile(Out, myProg.exe)
; Uncomment to use the following icon. Make sure the file path is correct and matches the installation of your AutoIt install path.
; #pragma compile(Icon, C:\Program Files\AutoIt3\Icons\au3.ico)
; #pragma compile(ExecLevel, highestavailable)
; #pragma compile(Compatibility, win7)
; #pragma compile(UPX, False)
#pragma compile(FileDescription, do - a time tracking helper for use with Speed4Trade ticket-system)
#pragma compile(ProductName, do)
#pragma compile(ProductVersion, 1.0)
#pragma compile(FileVersion, 1.0.0.3, 1.0.0.3) ; The last parameter is optional.
#pragma compile(LegalCopyright, © Juergen Albersdorfer)
#pragma compile(LegalTrademarks, 'Free as "Free" in "Free Beer"')
#pragma compile(CompanyName, 'Speed4Trade GmbH')
#pragma compile(Console, false)

$log = IniRead ( "do.ini", "default", "log", "true" )
If $log <> "false" Then
   FileWriteLine ( "do.log", @YEAR & "-" & @MON & "-" & @MDAY & " " & @HOUR & ":" & @MIN & ":" & @SEC & " - do " & $CmdLineRaw )
EndIf

If $CmdLine[0] = 0 Then
   printUsage()
   Exit
EndIf

$task = IniRead ( "do.ini", "default", "description", "default" )
If $CmdLine[0] = 2 Then
   $task = $CmdLine[2]
EndIf

Switch $CmdLine[1]
Case "configure"
   configure ( $CmdLine[2], $CmdLine[3] )
Case "show"
   showCurrent()
Case "start"
   ; delete ticket file
   FileDelete ( "ticket" )
Case "reset"
   ; delete ticket file
   FileDelete ( "ticket" )
Case "done"
   ; book expense
   bookExpense()
Case "else"
   ; book expense and start for global ticket
   bookExpense()
   $defaultticket = IniRead ( "do.ini", "default", "default-ticket", "44618" )
   startExpense($defaultticket, $task)
Case "continue", "c"
   ; continue work on the given Ticket
   bookExpense()
   $task = IniRead ( "do.ini", "default", "description", "default" )
   If $CmdLine[0] = 3 Then
	  $task = $CmdLine[3]
   EndIf
   startExpense($CmdLine[2], $task)
Case Else
   ; book expense and start for given ticket
   bookExpense()
   startExpense($CmdLine[1], $task)
   $openInBrowser = IniRead ( "do.ini", "default", "openTicketInBrowser", "false" )
   If $openInBrowser <> "false" Then
	  openInBrowser ( $CmdLine[1] )
   EndIf
EndSwitch

; To open the given Ticket-Nr. in the configured Browser
Func openInBrowser ( $tic )
   $browser = IniRead ( "do.ini", "browser", "exe", "firefox.exe" )
   $params = IniRead ( "do.ini", "browser", "params", "http://ticket-system/ticket_detail.php?id=%1" )
   $params = StringReplace ( $params, "%1", $tic )
   ShellExecute ( $browser, $params )
EndFunc

; To write the given Ticket-Nr. into the ticket-File
Func startExpense($tic, $task)
   IniWrite ( "ticket", "default", "ticket", $tic )
   IniWrite ( "ticket", "default", "task", $task )
EndFunc

; To book the time between the ticket-File Modification Date and now as expense to the ticket within the ticket-File.
Func bookExpense()

   $time = FileGetTime ( "ticket" )
   If @error <> 0 Then Return

   $curl = IniRead ( "do.ini", "default", "curl", "curl" )
   $url = IniRead ( "do.ini", "default", "url", "http://ticket-system/ajax/ticket_book_expense.php" )
   $defaultticket = IniRead ( "do.ini", "default", "default-ticket", "Undefined" )
   If $defaultticket = "Undefined" Then
	  MsgBox ( 0, "Fatal", "No default-ticket defined. Please define default-ticket in do.ini" )
	  Return
   EndIf

   $post = "todo=aufwand"
   $post &= "&aufwand_beschreibung=" & IniRead ( "ticket", "default", "task", "Undefined" )
   $post &= "&aufwand_firma=1"
   $post &= "&ticketnr=" & IniRead ( "ticket", "default", "ticket", $defaultticket )
   $expenseTime = getTimeSince ( $time[3], $time[4] )
   $post &= StringFormat ( "&aufwand_stunden=%02d%%3A%02d", $expenseTime[0], $expenseTime[1] )
   $post &= "&aufwand_datum=" & @MDAY & "." & @MON & "." & @YEAR
   $post &= "&aufwand_credits="
   $post &= "&aufwand_distanz="
   $post &= "&aufwand_fahrzeit="
   $post &= "&rnd=0.8285291696454633"

   $params = "-d" & " " & $post & " " & $url & " " & "--ntlm" & " " & "--negotiate" & " " & "-u :"

   $dry = IniRead ( "do.ini", "default", "dry-run", "false" )
   If $dry <> "true" Then
	  ShellExecute ( $curl, $params, "", "open", @SW_HIDE)
   Else
	  MsgBox ( 0, "do dry-run", $curl & " " & $params)
   EndIf

   FileDelete ( "ticket" )
EndFunc

; To show the current Ticket and Expense
Func showCurrent()
   $ticket = IniRead ( "ticket", "default", "ticket", "none" )
   $time = FileGetTime ( "ticket" )
   If @error = 0 Then
	  $task = IniRead ( "ticket", "default", "task", "undefined" )
	  $expenseTime = getTimeSince ( $time[3], $time[4] )
	  $expense = StringFormat ( "Aufwand: %02d:%02d", $expenseTime[0], $expenseTime[1] )
	  $started = StringFormat ( "Started: %02d:%02d", $time[3], $time[4] )
	  MsgBox ( 64, "Current Activity", $task & "@" & $ticket & " for " & $expense & "h" & " " & $started )
   Else
	  MsgBox ( 64, "Current Activity", "None" )
   EndIf
EndFunc

Func getTimeSince ( $hour, $minute )
   $minutes = (@HOUR - $hour) * 60 + (@MIN - $minute)
   Local $aArray[2]
   $aArray[0] = $minutes / 60
   $aArray[1] = Mod ( $minutes, 60 )
   Return $aArray
EndFunc

; To print out the usage information
Func printUsage()
   $msg =  "Usage:" & @CRLF
   $msg &=  "do start|else|done|show|<ticket> [task]" & @CRLF
   $msg &=  ""  & @CRLF
   $msg &=  "Parameters:" & @CRLF
   $msg &=  "  start    - to start from fresh. Forget everything (Time and Ticket). The first command to enter every morning ;)" & @CRLF
   $msg &=  "  else     - to start doing something else. Expense will be booked to the 'default-ticket'" & @CRLF
   $msg &=  "  done     - to book the last expense without starting into a new one. The last thing to do in the evening ;)" & @CRLF
   $msg &=  "  show     - to show the current ticket and expense" & @CRLF
   $msg &=  "  continue - (shortcut: c) to book the last expense and start time-tracking for that ticket without attempt to open that ticket in the browser." & @CRLF
   $msg &=  "  <ticket> - to book the last expense and start time-tracking for that ticket." & @CRLF
   $msg &=  "  [task]   - (optional) a task description for the booking of the expense." & @CRLF

   MsgBox ( 0, "do help", $msg )
EndFunc

; to change a configuration option in the do.ini
Func configure ( $key, $value, $section = "default" )
   IniWrite ( "do.ini", $section, $key, $value )
EndFunc