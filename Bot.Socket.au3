#include-once
#include <WinAPI.au3>
#include <WinAPIError.au3>
#include "Include\LibDebug.au3"
#include "Include\Json.au3"
#include "Include\WinHttp.au3"
#include "WinHttpExtensions.au3"

Global $gatewayUrl = ""
Global $hSession
Global $hConnection
Global $hRequest
Global $hSocket
Global $socketConnected = False
Global $socketBufferLength = 2048
Global $socketBuffer
Global $socketBufferBytesLeft
Global $socketDataReceived = Binary("")
Global $socketPayloadBuffer[0]
Global $socketReadCompleted = False
Global $hWinHttpStatusCallback
Global $socketHeartbeatInterval
Global $socketHeartbeatTimer
Global $funcOnMessage = Null

Func SocketInit()
	c("Socket connection initializing")
	GetGatewayUrl()
	
    ; Create session, connection and request handles
	c("Creating session")
	$hSession = _WinHttpOpen("Autoit discord bot", Default, Default, Default, $WINHTTP_FLAG_ASYNC)
	If Not $hSession Then
		ThrowApiError("SocketInit", "_WinHttpOpen")
	EndIf
	$hWinHttpStatusCallback = DllCallbackRegister("_WinhttpStatusCallback", "none", "handle;dword_ptr;dword;ptr;dword")
	_WinHttpSetStatusCallback($hSession, $hWinHttpStatusCallback)
	
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
	
	While Not $socketConnected
		Sleep(50)
	WEnd
	
	_WinHttpCloseHandle($hRequest)
    $hRequestHandle = 0
	
	SocketReceive()
	c("Socket initialization completed")
EndFunc

Func _WinhttpStatusCallback($hInternet, $iContext, $iInternetStatus, $pStatusInformation, $iStatusInformationLength)
	c("Received winhttp callback: ", 0)
    Switch $iInternetStatus
        Case $WINHTTP_CALLBACK_STATUS_CLOSING_CONNECTION
			c("CLOSING_CONNECTION, ", 0)
            c("Closing the connection to the server.")
			
        Case $WINHTTP_CALLBACK_STATUS_CONNECTED_TO_SERVER
			c("CONNECTED_TO_SERVER, ", 0)
            c("Successfully connected to the server.")
			
        Case $WINHTTP_CALLBACK_STATUS_CONNECTING_TO_SERVER
			c("CONNECTING_TO_SERVER, ", 0)
            c("Connecting to the server.")
			
        Case $WINHTTP_CALLBACK_STATUS_CONNECTION_CLOSED
			c("CONNECTION_CLOSED, ", 0)
            c("Successfully closed the connection to the server.")
			
        Case $WINHTTP_CALLBACK_STATUS_DATA_AVAILABLE
			c("DATA_AVAILABLE, ", 0)
            c("Data is available to be retrieved with WinHttpReadData.")
			
        Case $WINHTTP_CALLBACK_STATUS_HANDLE_CREATED
			c("HANDLE_CREATED, ", 0)
            c("An HINTERNET handle has been created.")
			
        Case $WINHTTP_CALLBACK_STATUS_HANDLE_CLOSING
			c("HANDLE_CLOSING, ", 0)
            c("This handle value has been terminated.")
			
        Case $WINHTTP_CALLBACK_STATUS_HEADERS_AVAILABLE
			c("HEADERS_AVAILABLE, ", 0)
            c("The response header has been received and is available with WinHttpQueryHeaders.")
			
			; TODO: Should check what the HTTP status code returned by the server is and behave accordingly,
			; CompleteUpgrade will fail if the HTTP status code is different than 101
			$hSocket = _WinHttpWebSocketCompleteUpgrade($hRequest, 0)
			If Not $hSocket Then
				ThrowApiError("_WinhttpStatusCallback", "_WinHttpWebSocketCompleteUpgrade")
			EndIf
			
			$socketConnected = True
			
        Case $WINHTTP_CALLBACK_STATUS_INTERMEDIATE_RESPONSE
			c("INTERMEDIATE_RESPONSE, ", 0)
            c("Received an intermediate (100 level) status code message from the server.")
			
        Case $WINHTTP_CALLBACK_STATUS_NAME_RESOLVED
			c("NAME_RESOLVED, ", 0)
            c("Successfully found the IP address of the server.")
			
        Case $WINHTTP_CALLBACK_STATUS_READ_COMPLETE
			c("READ_COMPLETE, ", 0)
            c("Data was successfully read from the server.")
            
            $socketReadCompleted = True
			
			Local $socketStatus = DllStructCreate($tagWINHTTP_WEB_SOCKET_STATUS, $pStatusInformation)
			Local $bytesRead = DllStructGetData($socketStatus, "dwBytesTransferred")
			Local $bufferType = DllStructGetData($socketStatus, "eBufferType")
			c("Received message of type: $", 1, $bufferType)
			
			$socketDataReceived &= BinaryMid(DllStructGetData($socketBuffer, 1), 1, $bytesRead)
			$socketBufferBytesLeft -= $bytesRead
			$socketBuffer = 0  ; Free the buffer

			; Check if the buffer contains the complete message
			If $bufferType = $WINHTTP_WEB_SOCKET_UTF8_MESSAGE_BUFFER_TYPE Then
				$socketBufferBytesLeft = $socketBufferLength
				ReDim $socketPayloadBuffer[UBound($socketPayloadBuffer) + 1]
				$socketPayloadBuffer[UBound($socketPayloadBuffer) - 1] = BinaryToString($socketDataReceived)
				$socketDataReceived = Binary("")
				c("Received gateway payload: $", 1, $socketPayloadBuffer[UBound($socketPayloadBuffer) - 1])
			EndIf
			
        Case $WINHTTP_CALLBACK_STATUS_RECEIVING_RESPONSE
			c("RECEIVING_RESPONSE, ", 0)
            c("Waiting for the server to respond to a request.")
			
        Case $WINHTTP_CALLBACK_STATUS_REDIRECT
			c("REDIRECT, ", 0)
            c("An HTTP request is about to automatically redirect the request.")
			
        Case $WINHTTP_CALLBACK_STATUS_REQUEST_ERROR
			c("REQUEST_ERROR, ", 0)
            c("An error occurred while sending an HTTP request.")
			
        Case $WINHTTP_CALLBACK_STATUS_REQUEST_SENT
			c("REQUEST_SENT, ", 0)
            c("Successfully sent the information request to the server.")
			
        Case $WINHTTP_CALLBACK_STATUS_RESOLVING_NAME
			c("RESOLVING_NAME, ", 0)
            c("Looking up the IP address of a server name.")
			
        Case $WINHTTP_CALLBACK_STATUS_RESPONSE_RECEIVED
			c("RESPONSE_RECEIVED, ", 0)
            c("Successfully received a response from the server.")
			
        Case $WINHTTP_CALLBACK_STATUS_SECURE_FAILURE
			c("SECURE_FAILURE, ", 0)
            c("One or more errors were encountered while retrieving a Secure Sockets Layer (SSL) certificate from the server.")
			
        Case $WINHTTP_CALLBACK_STATUS_SENDING_REQUEST
			c("SENDING_REQUEST, ", 0)
            c("Sending the information request to the server.")
			
        Case $WINHTTP_CALLBACK_STATUS_SENDREQUEST_COMPLETE
			c("SENDREQUEST_COMPLETE, ", 0)
            c("The request completed successfully.")
			
			Local $rtn
			$rtn = _WinHttpReceiveResponse($hRequest)
			If Not $rtn Then
				ThrowApiError("_WinhttpStatusCallback", "_WinHttpReceiveResponse")
			EndIf
			
        Case $WINHTTP_CALLBACK_STATUS_WRITE_COMPLETE
			c("WRITE_COMPLETE, ", 0)
            c("Data was successfully written to the server.")
			
		Case Else
			c("Undefined callback status")
    EndSwitch
EndFunc

Func SocketUpdate()
    If $socketReadCompleted Then
        $socketReadCompleted = False
        Sleep(100)
        SocketReceive()  ; Start receiving of the next payload
    EndIf
	ResolvePayloads()
	If $socketHeartbeatInterval And TimerDiff($socketHeartbeatTimer) > $socketHeartbeatInterval Then
		; $socketHeartbeatInterval = GetPayloadData().Item("heartbeat_interval")
		$socketHeartbeatTimer = TimerInit()
		SocketSend(MakePayload($OPCODE_HEARTBEAT))
	EndIf
EndFunc

Func ResolvePayloads()
	If Not HasPayload() Then
		Return
	EndIf
	Local $payload = GetPayload()
	Local $opCode = GetPayloadOpCodeFrom($payload)
	Local $data = GetPayloadDataFrom($payload)
	Switch $opCode
		Case $OPCODE_DISPATCH
		
        ; The gateway may request a heartbeat from the client in some situations by sending an Opcode 1 Heartbeat.
        ; When this occurs, the client should immediately send an Opcode 1 Heartbeat without waiting the remainder of the current interval.
		Case $OPCODE_HEARTBEAT
            $socketHeartbeatTimer = TimerInit()
            SocketSend(MakePayload($OPCODE_HEARTBEAT))
        
		Case $OPCODE_RECONNECT
		
		Case $OPCODE_INVALID_SESSION
		
		Case $OPCODE_HELLO
			$socketHeartbeatInterval = $data.Item("heartbeat_interval")
            $socketHeartbeatInterval = 4000
			$socketHeartbeatTimer = TimerInit()
		
        ; Any time the client sends a heartbeat,
        ; the gateway will respond with Opcode 11 Heartbeat ACK,
        ; a successful *acknowledgement* of their last heartbeat
		Case $OPCODE_HEARTBEAT_ACK
		
		Case Else
			c("Received payload of invalid opcode")
	EndSwitch
EndFunc

Func SocketReceive()
	$socketBuffer = DllStructCreate("byte[" & $socketBufferLength & "]")
	
	Local $rtn
	$rtn = _WinHttpWebSocketReceive($hSocket, $socketBuffer, Null, Null)
	
	If $rtn <> 0 Then
		ThrowApiError("SocketReceive", "_WinHttpWebSocketReceive")
	EndIf
EndFunc

Func SocketSend(ByRef $payload)
	Local $msg = Json_Encode($payload)
	Local $rtn = _WinHttpWebSocketSend($hSocket, _
									   $WINHTTP_WEB_SOCKET_UTF8_MESSAGE_BUFFER_TYPE, _
									   $msg)
	If $rtn <> 0 Then
		ThrowApiError("SocketSend", "_WinHttpWebSocketSend")
	EndIf
	c("Sent payload to the server: $", 1, $msg)
EndFunc

Func HasPayload()
	Return UBound($socketPayloadBuffer) > 0
EndFunc

Func GetPayload()
	; Get the oldest payload received which is the first one in the FIFO buffer array
	Local $payload = $socketPayloadBuffer[0]
	; Move all the other payloads up front and shrink the array
	For $i = 0 To UBound($socketPayloadBuffer) - 1 - 1
		$socketPayloadBuffer[$i] = $socketPayloadBuffer[$i + 1]
	Next
	ReDim $socketPayloadBuffer[UBound($socketPayloadBuffer) - 1]
	Return Json_Decode($payload)
EndFunc

Func GetPayloadDataFrom(ByRef $payload)
	Return Json_ObjGet($payload, "d")
EndFunc

Func GetPayloadOpCodeFrom(ByRef $payload)
	Return Json_ObjGet($payload, "op")
EndFunc

Func MakePayload($opCode, $data = Null)
	Local $newPayload = Json_ObjCreate()
	$newPayload.Add("op", $opCode)
	If $data Then
		$newPayload.Add("d", $data)
	Else
		$newPayload.Add("d", Json_ObjCreate())
	EndIf
	Return $newPayload
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
	Local $error = _WinAPI_GetLastError()
	Local $errorMsg = _WinAPI_GetLastErrorMessage()
	throw($funcName, "On " & $apiName, "Windows API error: " & $error, $errorMsg)
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
	
	If $hWinHttpStatusCallback Then DllCallbackFree($hWinHttpStatusCallback)
EndFunc