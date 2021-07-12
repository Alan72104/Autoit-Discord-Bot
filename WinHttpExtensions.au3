#include-once

Global Const $WINHTTP_OPTION_UPGRADE_TO_WEB_SOCKET = 114

Global Const $WINHTTP_WEB_SOCKET_BINARY_MESSAGE_BUFFER_TYPE = 0
Global Const $WINHTTP_WEB_SOCKET_BINARY_FRAGMENT_BUFFER_TYPE = 1
Global Const $WINHTTP_WEB_SOCKET_UTF8_MESSAGE_BUFFER_TYPE = 2
Global Const $WINHTTP_WEB_SOCKET_UTF8_FRAGMENT_BUFFER_TYPE = 3
Global Const $WINHTTP_WEB_SOCKET_CLOSE_BUFFER_TYPE = 4
Global Const $WINHTTP_WEB_SOCKET_BUFFER_TYPE = 5

Global Const $WINHTTP_WEB_SOCKET_SUCCESS_CLOSE_STATUS = 1000

Func _WinHttpSetOptionNoParams($hInternet, $iOption)
    Local $aCall = DllCall($hWINHTTPDLL__WINHTTP, "bool", "WinHttpSetOption", _
            "handle", $hInternet, "dword", $iOption, "ptr", 0, "dword", 0)
    If @error Or Not $aCall[0] Then Return SetError(4, 0, 0)
    Return 1
EndFunc   ;==>_WinHttpSetOptionNoParams

Func _WinHttpWebSocketCompleteUpgrade($hRequest, $pContext = 0)
    Local $aCall = DllCall($hWINHTTPDLL__WINHTTP, "handle", "WinHttpWebSocketCompleteUpgrade", _
            "handle", $hRequest, _
            "DWORD_PTR", $pContext)
    If @error Then Return SetError(@error, @extended, -1)
    Return $aCall[0]
EndFunc   ;==>_WinHttpWebSocketCompleteUpgrade

Func _WinHttpWebSocketSend($hSocket, $bufferType, $vData)
    Local $buffer = 0, $bufferLeft = 0
    If IsBinary($vData) = 0 Then $vData = StringToBinary($vData)
    $bufferLeft = BinaryLen($vData)
    If $bufferLeft > 0 Then
        $buffer = DllStructCreate("byte[" & $bufferLeft & "]")
        DllStructSetData($buffer, 1, $vData)
    EndIf

    Local $aCall = DllCall($hWINHTTPDLL__WINHTTP, "DWORD", "WinHttpWebSocketSend", _
            "handle", $hSocket, _
            "int", $bufferType, _
            "ptr", DllStructGetPtr($buffer), _
            "DWORD", $bufferLeft)
    If @error Then Return SetError(@error, @extended, -1)
    Return $aCall[0]
EndFunc   ;==>_WinHttpWebSocketSend

Func _WinHttpWebSocketReceive($hSocket, $buffer, ByRef $bytesRead, ByRef $bufferType)
    Local $aCall = DllCall($hWINHTTPDLL__WINHTTP, "handle", "WinHttpWebSocketReceive", _
            "handle", $hSocket, _
            "ptr", DllStructGetPtr($buffer), _
            "DWORD", DllStructGetSize($buffer), _
            "DWORD*", $bytesRead, _
            "int*", $bufferType)
    If @error Then Return SetError(@error, @extended, -1)
    $bytesRead = $aCall[4]
    $bufferType = $aCall[5]
    Return $aCall[0]
EndFunc   ;==>_WinHttpWebSocketReceive

Func _WinHttpWebSocketClose($hSocket, $iStatus, $tReason = 0)
    Local $aCall = DllCall($hWINHTTPDLL__WINHTTP, "handle", "WinHttpWebSocketClose", _
            "handle", $hSocket, _
            "USHORT", $iStatus, _
            "ptr", DllStructGetPtr($tReason), _
            "DWORD", DllStructGetSize($tReason))
    If @error Then Return SetError(@error, @extended, -1)
    Return $aCall[0]
EndFunc   ;==>_WinHttpWebSocketClose

Func _WinHttpWebSocketQueryCloseStatus($hSocket, ByRef $iStatus, ByRef $iReasonLengthConsumed, $tCloseReasonBuffer = 0)
    Local $aCall = DllCall($hWINHTTPDLL__WINHTTP, "handle", "WinHttpWebSocketQueryCloseStatus", _
            "handle", $hSocket, _
            "USHORT*", $iStatus, _
            "ptr", DllStructGetPtr($tCloseReasonBuffer), _
            "DWORD", DllStructGetSize($tCloseReasonBuffer), _
            "DWORD*", $iReasonLengthConsumed)
    If @error Then Return SetError(@error, @extended, -1)
    $iStatus = $aCall[2]
    $iReasonLengthConsumed = $aCall[5]
    Return $aCall[0]
EndFunc   ;==>_WinHttpWebSocketQueryCloseStatus