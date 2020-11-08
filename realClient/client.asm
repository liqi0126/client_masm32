.386
.model flat, stdcall
option casemap :none

include ws2_32.inc
include kernel32.inc
include windows.inc
include user32.inc
include masm32rt.inc
include msvcrt.inc
include gdi32.inc
include user32.inc
include kernel32.inc
include comctl32.inc
include msvcrt.inc
include ole32.inc

include header.inc

includelib ws2_32.lib
includelib kernel32.lib
includelib masm32.lib
includelib user32.lib
includelib wsock32.lib
includelib msvcrt.lib


ExitProcess PROTO STDCALL:DWORD
clientFriendReply PROTO :PTR BYTE, :DWORD

;==================== DATA =======================

.const
BUFSIZE EQU 104857600

.data
; message
ERR_BUILD_SOCKET	db "Fail to Open Socket", 0
ERR_CONNECT			db "Fail to connect IP address", 0


FRIEND_REQUEST_HEADER	db "ºÃÓÑÉêÇë", 0
FRIEND_REQUEST_CONTENT	db "ÏëÒªÌí¼ÓÄúÎªºÃÓÑ", 0

currentUser db 128 dup(0)
connSocket dd ?

DEBUG_MSG db "%s", 0ah, 0dh, 0

;=================== CODE =========================
.code

printRecvMsg PROC
	LOCAL @szBuffer:DWORD

	mov @szBuffer, alloc(BUFSIZE)

	invoke RtlZeroMemory, @szBuffer, BUFSIZE
	invoke recv, connSocket, @szBuffer, BUFSIZE, 0
	invoke crt_printf, addr DEBUG_MSG, @szBuffer

	free @szBuffer
	ret
printRecvMsg ENDP


;------------------------------------------------------------------------------
clientRecvRoomTalk PROC msgBuffer:ptr byte
; format: sourceUser, Msg
;------------------------------------------------------------------------------
	LOCAL @tmpCmd:dword
	LOCAL @sourceUser[256]:byte
	LOCAL @msgContent:dword
	
	mov @msgContent, alloc(BUFSIZE)

	invoke crt_sscanf, msgBuffer, offset MSG_FORMAT6, addr @tmpCmd, addr @sourceUser, @msgContent
	invoke SendMessage, hWinMain, WM_APPENDROOMMSG, addr @sourceUser, @msgContent

	free @msgContent ; É¾Âð?
	ret
clientRecvRoomTalk ENDP


;------------------------------------------------------------------------------
clientRecv1To1Talk PROC msgBuffer:ptr byte
; format: sourceUser, Msg
;------------------------------------------------------------------------------
	LOCAL @tmpCmd:dword
	LOCAL @sourceUser[256]:byte
	LOCAL @msgContent:dword

	mov @msgContent, alloc(BUFSIZE)

	invoke crt_sscanf, msgBuffer, offset MSG_FORMAT6, addr @tmpCmd, addr @sourceUser, @msgContent
	invoke SendMessage, hWinMain, WM_APPEND1TO1MSG, addr @sourceUser, @msgContent

	free @msgContent ; É¾Âð?

	ret
clientRecv1To1Talk ENDP



;------------------------------------------------------------------------------
clientRecvFriendApply PROC msgBuffer:ptr byte
; format: sourceUsr
;------------------------------------------------------------------------------
	LOCAL @tmpCmd:dword
	LOCAL @sourceUser[256]:byte
	LOCAL @content[256]:byte

	invoke crt_sscanf, msgBuffer, offset MSG_FORMAT1, addr @tmpCmd, addr @sourceUser
	invoke crt_sprintf, addr @content, offset MSG_FORMAT7, addr @sourceUser, addr FRIEND_REQUEST_CONTENT

	invoke MessageBox, NULL, addr @content, addr FRIEND_REQUEST_HEADER, MB_YESNO
	.if eax == IDYES
		invoke SendMessage, hWinMain, WM_APPENDFRIEND, addr @sourceUser, 0
		invoke clientFriendReply, addr @sourceUser, 1
	.elseif eax == IDNO
		invoke clientFriendReply, addr @sourceUser, 0
	.endif

	ret
clientRecvFriendApply ENDP


;------------------------------------------------------------------------------
clientRecvFriendList PROC msgBuffer:ptr byte
; format: 5 F1:S1 F2:S2 ......
;------------------------------------------------------------------------------
	LOCAL @userName[256]:byte
	LOCAL @cursor:dword
	LOCAL @userLen:dword

	mov eax, msgBuffer
	mov @cursor, eax
	add @cursor, 2
	.while 1
		invoke crt_strstr, @cursor, offset SEP1
		.break .if eax == 0
		mov ebx, @cursor
		push eax
		sub eax, ebx
		mov @userLen, eax
		invoke crt_strncpy, addr @userName, @cursor, @userLen
		
		pop eax
		mov @cursor, eax
		inc eax
		mov ebx, 0
		mov bl, [eax]
		sub ebx, 48 ; ASCII to int
		invoke SendMessage, hWinMain, WM_APPENDFRIEND, addr @userName, ebx
		add @cursor, 3
	.endw

	ret
clientRecvFriendList ENDP


;------------------------------------------------------------------------------
clientRecvFriendNotify PROC msgBuffer:ptr byte
; format: 
;------------------------------------------------------------------------------
	LOCAL @tmpCmd:dword
	LOCAL @sourceUser[256]:byte
	LOCAL @notifyID:dword

	invoke crt_sscanf, msgBuffer, offset MSG_FORMAT4, addr @tmpCmd, addr @sourceUser, addr @notifyID
	invoke SendMessage, hWinMain, WM_CHANGEFRISTATUS, addr @sourceUser, @notifyID

	ret
clientRecvFriendNotify ENDP


;------------------------------------------------------------------------------
serviceThread PROC sockfd:dword
; thread to receive message from server
;------------------------------------------------------------------------------
	LOCAL @stFdset:fd_set, @stTimeval:timeval
    LOCAL @szBuffer:dword
	LOCAL @msgContent:dword
	LOCAL @serverCmd:byte

	mov @szBuffer, alloc(BUFSIZE)
	mov @msgContent, alloc(BUFSIZE)

	.while 1
;		mov @stFdset.fd_count, 1
;		push sockfd
;		pop @stFdset.fd_array
;		mov @stTimeval.tv_usec,200*1000 ;ms
;		mov @stTimeval.tv_sec,0
;		invoke select, 0, addr @stFdset, NULL, NULL, addr @stTimeval ; wait for server cmd
;
;		.break .if eax == SOCKET_ERROR
;		.continue .if !eax

		invoke RtlZeroMemory, @szBuffer, BUFSIZE
		invoke recv, sockfd, @szBuffer, BUFSIZE,0
		.break .if eax == SOCKET_ERROR
		.break .if !eax

		mov eax, @szBuffer
		mov bl, [eax]
		mov @serverCmd, bl

		.if @serverCmd == SERVER_ROOM_TALK_ASCII
			invoke clientRecvRoomTalk, @szBuffer

		.elseif @serverCmd == SERVER_1TO1_TALK_ASCII
			invoke clientRecv1To1Talk, @szBuffer

		.elseif @serverCmd == SERVER_FRIEND_APPLY_ASCII
			invoke clientRecvFriendApply, @szBuffer

		.elseif @serverCmd == SERVER_FRIEND_LIST_ASCII
			invoke clientRecvFriendList, @szBuffer

		.elseif @serverCmd == SERVER_FRIEND_NOTIFY_ASCII
			invoke clientRecvFriendNotify, @szBuffer
		.endif

	.endw
   
    invoke closesocket, sockfd
	free @szBuffer
	free @msgContent
    ret
serviceThread ENDP


;---------------------------------------------------------------
clientLogIn PROC szAddr:PTR BYTE, szPort:DWORD, username:PTR BYTE, password:PTR BYTE
; sign in to server
;---------------------------------------------------------------
	LOCAL @stWsa:WSADATA
    LOCAL @stSin:sockaddr_in
	LOCAL @szBuffer[256]:byte

	; build socket
	invoke WSAStartup,101h,addr @stWsa
	invoke socket, AF_INET, SOCK_STREAM, 0
	.if eax == INVALID_SOCKET
        invoke MessageBox, NULL, addr ERR_BUILD_SOCKET, addr ERR_BUILD_SOCKET, MB_OK
        mov eax, 0
        ret
    .endif
	mov connSocket, eax

	; convert address
	invoke RtlZeroMemory,addr @stSin,sizeof @stSin
	invoke inet_addr, szAddr
	mov @stSin.sin_addr, eax
	invoke htons, szPort
	mov @stSin.sin_port, ax
	mov @stSin.sin_family, AF_INET
	
	invoke connect, connSocket, addr @stSin, sizeof @stSin
	.if eax == SOCKET_ERROR
        invoke WSAGetLastError
        .if eax != WSAEWOULDBLOCK
            invoke closesocket, connSocket
            mov connSocket, 0
            invoke MessageBox, NULL, addr ERR_CONNECT, addr ERR_CONNECT, MB_OK
            mov eax,0
            ret
        .endif
    .endif

	invoke crt_sprintf, addr @szBuffer, offset MSG_FORMAT3, CLIENT_LOGIN, username, password
	invoke crt_strlen, addr @szBuffer
	invoke send, connSocket, addr @szBuffer, eax, 0

	invoke RtlZeroMemory, addr @szBuffer, sizeof @szBuffer
	invoke recv, connSocket, addr @szBuffer, sizeof @szBuffer, 0

	.if @szBuffer[0] == '0'
		invoke closesocket,connSocket
	    invoke MessageBox, NULL, addr @szBuffer, addr @szBuffer, MB_OK
		mov eax, 0
	.else
		invoke crt_strcpy, offset currentUser, username
		invoke CreateThread, NULL, 0, offset serviceThread, connSocket, NULL, esp
		;invoke CloseHandle, eax
		mov eax, 1
	.endif

	ret
clientLogIn ENDP


;---------------------------------------------------------------
clientSignIn PROC szAddr:PTR BYTE, szPort:DWORD, username:PTR BYTE, password:PTR BYTE
; sign in to server
;---------------------------------------------------------------
	LOCAL @stWsa:WSADATA
    LOCAL @stSin:sockaddr_in
	LOCAL @szBuffer[256]:byte

	; build socket
	invoke WSAStartup,101h,addr @stWsa
	invoke socket, AF_INET, SOCK_STREAM, 0
	.if eax == INVALID_SOCKET
        invoke MessageBox, NULL, addr ERR_BUILD_SOCKET, addr ERR_BUILD_SOCKET, MB_OK
        mov eax, 0
        ret
    .endif
	mov connSocket, eax

	; convert address
	invoke RtlZeroMemory,addr @stSin,sizeof @stSin
	invoke inet_addr, szAddr
	mov @stSin.sin_addr, eax
	invoke htons, szPort
	mov @stSin.sin_port, ax
	mov @stSin.sin_family, AF_INET
	
	invoke connect, connSocket, addr @stSin, sizeof @stSin
	.if eax == SOCKET_ERROR
        invoke WSAGetLastError
        .if eax != WSAEWOULDBLOCK
            invoke closesocket, connSocket
            mov connSocket, 0
            invoke MessageBox, NULL, addr ERR_CONNECT, addr ERR_CONNECT, MB_OK
            mov eax,0
            ret
        .endif
    .endif

	invoke crt_sprintf, addr @szBuffer, offset MSG_FORMAT3, CLIENT_SIGNUP, username, password
	invoke crt_strlen, addr @szBuffer
	invoke send, connSocket, addr @szBuffer, eax, 0

	invoke RtlZeroMemory, addr @szBuffer, sizeof @szBuffer
	invoke recv,connSocket, addr @szBuffer, sizeof @szBuffer, 0

	.if @szBuffer[0] == '0'
	    invoke MessageBox, NULL, addr @szBuffer, addr @szBuffer, MB_OK
		mov eax, 0
	.else
		mov eax, 1
	.endif

	invoke closesocket, connSocket
	ret
clientSignIn ENDP


;------------------------------------------------------------------------------
clientSend1To1Msg PROC username:PTR BYTE, msg:PTR BYTE
; format: username XXX
;------------------------------------------------------------------------------
	LOCAL @szBuffer:dword

	mov @szBuffer, alloc(BUFSIZE)

	invoke crt_sprintf, @szBuffer, offset MSG_FORMAT3, CLIENT_1TO1_TALK, username, msg
	invoke crt_strlen, @szBuffer
	invoke send, connSocket, @szBuffer, eax, 0

	free @szBuffer
	mov eax, 1
    ret
clientSend1To1Msg ENDP


;------------------------------------------------------------------------------
clientSendChatroomMsg PROC msg:PTR BYTE
; format: Msg
;------------------------------------------------------------------------------
	LOCAL @szBuffer:dword

	mov @szBuffer, alloc(BUFSIZE)

	invoke crt_sprintf, @szBuffer, offset MSG_FORMAT1, CLIENT_ROOM_TALK, msg
	invoke crt_strlen, @szBuffer
	invoke send, connSocket, @szBuffer, eax, 0

	free @szBuffer
	mov eax, 1
    ret
clientSendChatroomMsg ENDP

;------------------------------------------------------------------------------
clientAddFriend PROC username:PTR BYTE
; add new friend
;------------------------------------------------------------------------------
	LOCAL @szBuffer[1024]:dword

	invoke crt_sprintf, addr @szBuffer, offset MSG_FORMAT1, CLIENT_FRIEND_APPLY, username
	invoke crt_strlen, addr @szBuffer
	invoke send, connSocket, addr @szBuffer, eax, 0

	mov eax, 1
    ret
clientAddFriend ENDP


;------------------------------------------------------------------------------
clientFriendReply PROC username:PTR BYTE, accepted:DWORD
; friend application reply
;------------------------------------------------------------------------------
	LOCAL @szBuffer[1024]:dword

	invoke crt_sprintf, addr @szBuffer, offset MSG_FORMAT4, CLIENT_FRIEND_REPLY, username, accepted
	invoke crt_strlen, addr @szBuffer
	invoke send, connSocket, addr @szBuffer, eax, 0

	mov eax, 1
    ret
clientFriendReply ENDP


;------------------------------------------------------------------------------
clientDeleteFriend PROC username:PTR BYTE
; delete friend
;------------------------------------------------------------------------------
	LOCAL @szBuffer[1024]:dword

	invoke crt_sprintf, addr @szBuffer, offset MSG_FORMAT1, CLIENT_FRIEND_DELETE, username
	invoke crt_strlen, addr @szBuffer
	invoke send, connSocket, addr @szBuffer, eax, 0

	mov eax, 1
    ret
clientDeleteFriend ENDP


END