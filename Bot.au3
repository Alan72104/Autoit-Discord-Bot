#include-once
#include "Include\LibDebug.au3"
#include "Bot.Socket.au3"
#include "Bot.Socket.OpCodes.au3"
#include "Bot.MessageProcessor.au3"

Global $token = ""
Global $heartbeatInterval, $heartbeatTimer
HotKeySet("{F7}", "Terminate")
OnAutoItExitRegister("Dispose")

Func SendIdentify()
	Local $identifyPayload = MakePayload($OPCODE_IDENTIFY)
		Local $identifyData = Json_ObjCreate()
			$identifyData.Add("token", $token)
			Local $identifyDataProps = Json_ObjCreate()
				$identifyDataProps.Add("$os", "windows")
				$identifyDataProps.Add("$browser", "autoit")
				$identifyDataProps.Add("$device", "autoit")
			$identifyData.Add("properties", $identifyDataProps)
			$identifyData.Add("intents", 0)
			Local $identifyDataPresence = Json_ObjCreate()
				Local $identifyDataPresenceActivities[0]
					Local $identifyDataPresenceActivities1 = Json_ObjCreate()
						$identifyDataPresenceActivities1.Add("name", "testt")
						$identifyDataPresenceActivities1.Add("type", 1)
					ArrayAdd($identifyDataPresenceActivities, $identifyDataPresenceActivities1)
				$identifyDataPresence.Add("activities", $identifyDataPresenceActivities)
				$identifyDataPresence.Add("status", "idle")
				$identifyDataPresence.Add("afk", False)
			$identifyData.Add("presence", $identifyDataPresence)
		Json_ObjPut($identifyPayload, "d", $identifyData)
	SocketSend($identifyPayload)
EndFunc

Func Main()
    $token = IniRead(@ScriptDir & "\Config.ini", "Token", "Token", "")
    If $token = "" Then
        throw("Main", "Token not found", "Please put your bot token in the ""Token"" key of the ""Token"" section in the ""Config.ini"" file")
        Exit
    EndIf
	SocketInit()
	While 1
		SocketUpdate()
		CheckMessage()
		; If TimerDiff($heartbeatTimer) >= $heartbeatInterval Then
			; $heartbeatTimer = TimerInit()
			; SocketSend(MakePayload($OPCODE_HEARTBEAT))
			; SocketReceive()
		; EndIf
	WEnd
EndFunc

Main()

Func ArrayAdd(ByRef $a, $ele)
	ReDim $a[UBound($a) + 1]
	$a[UBound($a) - 1] = $ele
EndFunc

Func Dispose()
	SocketClose()
Endfunc

Func Terminate()
	Exit
EndFunc