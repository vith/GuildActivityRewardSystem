#Include <Array.au3>

;;;; Configuration Start
$weeknumber = 12
$winners = StringSplit("Onï Crenix Sheina Watapal Vrez Lueshion Ziri Omnishadow Wrathfull Disrupt Ruri Xtczr Frostmore Locknloadz Dano Melinn Contrololol Ellaman Worgenfleamn Itachii Eunomic Lightcaster Vith Shamuri Arinnar ßew Qali Ouroborous Caryn Kraizee Phatnipz", " ", 2)
$prizeamounts = StringSplit("2500 2000 1500 1000 1000 500 500 500 500 500 200 200 200 200 200", " ", 2)
$passers = StringSplit("Vith Sakurakun Watapal", " ", 2)
$self = "Vith"
;;;; Configuration End

;; Note: You'll also need to change the pixel offsets throughout the code if your Mailbox window isn't where mine was.

_ArrayReverse($prizeamounts)
Sleep(10000)
$testmode = False

Func GetOrdinal($i)
	$i = Int($i)
	If Mod($i, 100) > 10 And Mod($i, 100) < 20 Then
		Return $i & 'th'
	Else
		Switch Mod($i, 10)
		Case 1
			Return $i & 'st'
		Case 2
			Return $i & 'nd'
		Case 3
			Return $i & 'rd'
		Case Else
			Return $i & 'th'
		EndSwitch
	EndIf
EndFunc

$rank = 0
For $w In $winners
	$rank = $rank + 1
	$passer = False
	For $p In $passers
		If $p == $w Then
			$passer = True
		EndIf
	Next
	
	If $w <> $self Then
		If $passer Then
			$prize = $prizeamounts[UBound($prizeamounts) - 1]
		Else
			$prize = _ArrayPop($prizeamounts)
		EndIf
		$subject = Stringformat("Week %u Guild Activity Reward", $weeknumber)
		$body = StringFormat("Congratulations, you placed %s in week %u's guild activity rankings.", GetOrdinal($rank), $weeknumber)
		MouseClick("left", 154, 161) ; To:
		Send("{CTRLDOWN}a{CTRLUP}{DELETE}") ; To:
		
		Send($w)
		Send("{DELETE}")
		Send("{TAB}")
		If $testmode Then Send("{ENTER}")
		Sleep(100)
		Send("{CTRLDOWN}a{CTRLUP}{DELETE}") ; Subject:
		Send($subject)
		Send("{TAB}")
		If $testmode Then Send("{ENTER}")
		Sleep(100)
		Send("{CTRLDOWN}a{CTRLUP}{DELETE}") ; <Body>
		Send($body)
		If $passer Then
			Send(StringFormat("{ENTER}{ENTER}(You passed on %ug prize)", $prize))
		EndIf
		Send("{TAB}")
		If $testmode Then Send("{ENTER}")
		Sleep(100)
		Send("{CTRLDOWN}a{CTRLUP}{DELETE}") ; <Gold>
		If Not $passer Then
			Send($prize)
		EndIf
		Send("{TAB}")
		Sleep(100)
		Send("{CTRLDOWN}a{CTRLUP}{DELETE}") ; <Silver>
		Send("{TAB}")
		Sleep(100)
		Send("{CTRLDOWN}a{CTRLUP}{DELETE}") ; <Copper>
		Sleep(100)
		If $testmode Then Send("{ENTER}")
		Sleep(100)
		If Not $testmode Then
			MouseClick("left", 226, 528) ; [Send]
			Sleep(1000)
			If NOT $passer Then
				MouseClick("left", 580, 207) ; [Accept]
			EndIf
		EndIf
		If $testmode Then Send("{ENTER}")
		Sleep(1500)
	EndIf
	
	If Not UBound($prizeamounts) Then ExitLoop
Next