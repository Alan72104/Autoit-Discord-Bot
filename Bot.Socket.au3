#include-once
#include <WinAPI.au3>
#include <WinAPIError.au3>
#include "Include\LibDebug.au3"
#include "Include\Json.au3"
#include "Include\WinHttp.au3"
#include "WinHttpExtensions.au3"

Global $gatewayUrl = ""
Global $hSession = 0
Global $hConnection = 0
Global $hRequest = 0
Global $hSocket = 0
Global $iError = 0
Global Const $bufferLength = 2048
Global $payload = ""

Func SocketInit()
	c("Socket connection initializing")
	GetGatewayUrl()
	
    ; Create session, connection and request handles
	c("Creating session")
	$hSession = _WinHttpOpen("Autoit discord bot", $WINHTTP_ACCESS_TYPE_DEFAULT_PROXY)
	If Not $hSession Then
		ThrowApiError("SocketInit", "_WinHttpOpen")
	EndIf
	
	c("Making connection")
	$hConnection = _WinHttpConnect($hSession, $gatewayUrl, $INTERNET_DEFAULT_HTTP_PORT)
	If Not $hConnection Then
		ThrowApiError("SocketInit", "_WinHttpConnect")
	EndIf
	
	c("Opening request")
	$hRequest = _WinHttpOpenRequest($hConnection, "GET", "/?v=9&encoding=json", "")
	If Not $hConnection Then
		ThrowApiError("SocketInit", "_WinHttpOpenRequest")
	EndIf
	
	Local $rtn
    ; Request protocol upgrade from http to websocket
	c("Upgrading protocol")
	$rtn = _WinHttpSetOptionNoParams($hRequest, $WINHTTP_OPTION_UPGRADE_TO_WEB_SOCKET)
	If Not $rtn Then
		ThrowApiError("SocketInit", "_WinHttpSetOption")
	EndIf
	
	; Perform websocket handshake by sending a request and receiving server's response
	c("Socket handshaking")
	$rtn = _WinHttpSendRequest($hRequest)
	If Not $rtn Then
		ThrowApiError("SocketInit", "_WinHttpSendRequest")
	EndIf
	
	$rtn = _WinHttpReceiveResponse($hRequest)
	If Not $rtn Then
		ThrowApiError("SocketInit", "_WinHttpReceiveResponse")
	EndIf
	
	; TODO: Should check what the HTTP status code returned by the server is and behave accordingly,
    ; CompleteUpgrade will fail if the HTTP status code is different than 101
	$hSocket = _WinHttpWebSocketCompleteUpgrade($hRequest, 0)
	If Not $hSocket Then
		ThrowApiError("SocketInit", "_WinHttpWebSocketCompleteUpgrade")
	EndIf
	
	_WinHttpCloseHandle($hRequest)
    $hRequestHandle = 0
	
	_WinHttpSetTimeouts($hSession, Default, Default, Default, 200)
	
	c("Socket initialization completed")
EndFunc

Func SocketReceive()
	Local $bufferLeft = $bufferLength
    Local $buffer = 0
	Local $bufferType = 0
	Local $bytesRead = 0
	Local $dataReceived = Binary("")
	Local $rtn = 0
	
    Do
        If $bufferLeft = 0 Then
            throw("SocketReceive", "Buffer overflowed")
			Exit
        EndIf

        $buffer = DllStructCreate("byte[" & $bufferLength & "]")

        $rtn = _WinHttpWebSocketReceive($hSocket, _
										$buffer, _
										$bytesRead, _
										$bufferType)
        If @error Or $rtn <> 0 Then
            ThrowApiError("SocketReceive", "_WinHttpWebSocketReceive")
            Return False
        EndIf
		
        $dataReceived &= BinaryMid(DllStructGetData($buffer, 1), 1, $bytesRead)
        $buffer = 0  ; Free the buffer

        $bufferLeft -= $bytesRead
    Until $bufferType <> $WINHTTP_WEB_SOCKET_UTF8_FRAGMENT_BUFFER_TYPE
	
	If $bufferType <> $WINHTTP_WEB_SOCKET_UTF8_MESSAGE_BUFFER_TYPE Then
		throw("SocketReceive", iv("Received unexpected buffer type: $", $bufferType))
	EndIf
	
	$payload = BinaryToString($dataReceived)
	c("Received gateway payload: $", 1, $payload)
EndFunc

Func SocketSend($msg)
	Local $rtn = _WinHttpWebSocketSend($hSocket, _
									   $WINHTTP_WEB_SOCKET_UTF8_MESSAGE_BUFFER_TYPE, _
									   $msg)
	If Not $rtn Then
		ThrowApiError("SocketSend", "_WinHttpWebSocketSend")
	EndIf
	c("Sent message to the server: ", 1, $msg)
EndFunc

Func GetGatewayUrl()
	Local $req = ObjCreate("winhttp.winhttprequest.5.1")
	$req.Open("GET", "https://discord.com/api/gateway", False)
	$req.Send()
	$gatewayUrl = Json_ObjGet(Json_Decode($req.ResponseText), "url")
	$gatewayUrl = StringReplace($gatewayUrl, "wss://", "")
	If $gatewayUrl = "" Then
		throw("GetGatewayUrl", "Cannot retrieve discord gateway URL")
		Exit
	EndIf
EndFunc

Func ThrowApiError($funcName, $apiName)
	$error = _WinAPI_GetLastError()
	throw($funcName, "On " & $apiName, "Windows API error: " & $error)
	Exit
EndFunc

Func SocketClose()
	If $hSocket Then
		_WinHttpWebSocketClose($hSocket, $WINHTTP_WEB_SOCKET_SUCCESS_CLOSE_STATUS)
	
		Local $status = 0
		Local $reasonLength = 0
		Local $reasonBuffer = DllStructCreate("byte[123]")
		_WinHttpWebSocketQueryCloseStatus($hSocket, _
										  $status, _
										  $reasonLength, _
										  $reasonBuffer)
		c("The server closed the socket with status: $, reason: $", 1, $status, _
		  BinaryToString(BinaryMid(DllStructGetData($reasonBuffer, 1), 1, $reasonLength)))
	EndIf
	
    If $hRequest Then _WinHttpCloseHandle($hRequest)
    If $hSocket Then _WinHttpCloseHandle($hSocket)
    If $hConnection Then _WinHttpCloseHandle($hConnection)
EndFunc

Func GetPayload()
	Return Json_Decode($payload)
EndFunc

Func GetPayloadData()
	Return Json_ObjGet(GetPayload(), "d")
EndFunc