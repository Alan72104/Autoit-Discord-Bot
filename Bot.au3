#include "Include\LibDebug.au3"
#include "Bot.Socket.au3"

HotKeySet("{F7}", "Terminate")
OnAutoItExitRegister("Dispose")

Func Main()
	SocketInit()
	SocketReceive()
	c(GetPayloadData().Item("heartbeat_interval"))
EndFunc

Main()

Func Dispose()
	SocketClose()
Endfunc

Func Terminate()
	Exit
EndFunc