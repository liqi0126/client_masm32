.386
.model flat, stdcall
;区分大小写
option casemap :none

include ws2_32.inc
include kernel32.inc
include windows.inc
include user32.inc
include msvcrt.inc

includelib ws2_32.lib
includelib kernel32.lib
includelib masm32.lib
includelib user32.lib
includelib msvcrt.lib


ExitProcess PROTO STDCALL:DWORD


WM_APPENDFRIEND = WM_USER + 1
WM_APPENDMSG = WM_USER + 2
WM_CHANGESTATUS = WM_USER + 3

parseFriendList PROTO :PTR BYTE

;==================== DATA =======================

.const
BufSize EQU 80


.data
extern hWinMain:dword

bufferSize=104857600

szConnect db "连接",0
 
szDisConnect db "断开",0
 
szErrSocket db "error !",0
szErrBind db"error bind !",0
szErrConnect db "error connect !",0
 
szAddr db 30 DUP(0)
serverPort dw ?
 
szClient db "Client: %s",0dh,0ah,0
szServer db "Server: %s",0dh,0ah,0

buffer BYTE BufSize DUP(?),0,0
stdInHandle HANDLE ?
bytesRead   DWORD ?

hint_connect byte "You connect!",0dh,0ah,0
hint_fromServer byte "from server: ",0
hint_login byte "You are trying to login",0dh,0ah,0

signal_signin byte "1",0
signal_login byte "0",0
signal_sendtext byte "1 ",0
signal_addfriend byte "2 ",0
signal_getFriendList byte "4 ",0
signal_tab byte " ",0


test_msg byte "1 wangwang jkdfdhfjdshfdjsf",0
test_content byte 100 dup(?)
test_user byte 100 dup(?)

test_friendList byte "wangwang 0 qq 1 hdhhdfhh 0",0

connSocket dd  ?
userlist byte 1024 dup(?)


send_buffer DWORD ?
recv_buffer DWORD ?

test_debug byte "what'swrong",0dh,0ah,0

;=================== CODE =========================
.code

setIP PROC szbuffer:ptr byte, portnum:word
	invoke crt_strcpy, addr szAddr, szbuffer
	mov ax, portnum
	mov serverPort, ax
	ret
setIP ENDP

;------------------------------------------------------------------
msgParser PROC USES eax ebx edx,_buffer:ptr byte
; 处理服务端返回的消息
;------------------------------------------------------------------
    LOCAL _username:PTR BYTE
    LOCAL _content:PTR BYTE

	mov eax, _buffer
	mov bl, [eax]
	.if bl == 49
		 ; 文字消息类型
		 mov edx, eax
		 add edx, 2
		 push edx
		 mov bl, [edx]
		 ; 解析对方用户名，将用户名存入用户名缓冲区
		 .while bl != 0
			.if bl == 32                
				mov bl, 00
                dec edx
				mov [edx], bl
				mov eax, edx
				inc eax
				pop edx
				push eax
                ;invoke crt_strcpy,_username,edx
                mov _username,edx
				.break
			.endif
			mov bl, [edx]
			inc edx
		 .endw
		 pop edx
		 ; 将消息文本复制到内容缓冲区
		 ;invoke crt_strcpy, _content, edx
         mov _content,edx
         pushad
         invoke crt_strlen,_content
		 invoke SendMessage, hWinMain, WM_APPENDMSG,  _username, _content
         ;invoke AppendMsg,_username,_content,eax,0
         popad
		 ret
	.elseif bl == 51
		; 加好友
		 mov edx, eax
		 add edx, 2
		 push edx
		 mov bl, [edx]
		 ; 解析对方用户名，将用户名存入用户名缓冲区
		 .while bl != 0
			.if bl == 32                
				mov bl, 00
                dec edx
				mov [edx], bl
				mov eax, edx
				inc eax
				pop edx
				push eax
                ;invoke crt_strcpy,_username,edx
                mov _username,edx
				;invoke nameToFd, edx, targetfd
				.break
			.endif
			mov bl, [edx]
			inc edx
		 .endw
		 pop edx
		 ; 将消息文本复制到内容缓冲区
		 ;invoke crt_strcpy, _content, edx
         mov _content,edx
		 mov eax, 1

pushad
         mov eax,_content
		 mov bl,[eax]
		 .if bl==48
			invoke SendMessage, hWinMain, WM_APPENDFRIEND, _username, 0
		 .elseif bl==49
			invoke SendMessage, hWinMain, WM_APPENDFRIEND, _username, 1
		 .endif
popad
		ret
	.elseif bl == 52
		; 好友上线
		mov edx, eax
		add edx, 2
		;invoke crt_strcpy, _username, edx
        mov _username,edx
		mov eax, 3
        ; 传入0是离线，1是在线
		invoke SendMessage, hWinMain, WM_CHANGESTATUS, _username, 1
		ret
	.elseif bl == 53
		; 好友下线
		mov edx, eax
		add edx, 2
		;invoke crt_strcpy, _username, edx
        mov _username,edx
		mov eax, 3
        ; 传入0是离线，1是在线
		invoke SendMessage, hWinMain, WM_CHANGESTATUS, _username, 0

		ret
	.endif
	ret
msgParser ENDP



;------------------------------------------------------------------------------
chat_getFriendList PROC 
; 用户获取好友列表
; 发送指令： 3 xiaohong 
; 发送请求成功，eax=1；否则为0
;------------------------------------------------------------------------------
    invoke parseFriendList,addr userlist
    mov eax,1
    ret
chat_getFriendList ENDP



;------------------------------------------------------------------------------
chat_recvmsg PROC _hSocket
; 用户收到服务器发来的消息
; 并处理消息
;------------------------------------------------------------------------------
    
    ; 接收用户列表
	invoke RtlZeroMemory,addr userlist,sizeof userlist
	invoke recv,_hSocket,addr userlist,sizeof userlist,0
    .if userlist[0]!=32

        invoke chat_getFriendList
    .endif
 
    ;mov recv_buffer,alloc(bufferSize)
    invoke crt_malloc,bufferSize
    mov recv_buffer,eax

	.while TRUE
        ; 存入全局
		invoke RtlZeroMemory,recv_buffer,bufferSize
		invoke recv,_hSocket,recv_buffer,bufferSize,0

        ;invoke msgParser,addr @szBuffer,addr @username,addr @content
        invoke msgParser,recv_buffer

	.endw
    
    invoke closesocket,_hSocket
    ret

chat_recvmsg ENDP



;---------------------------------------------------------------
chat_login PROC username:PTR BYTE,password:PTR BYTE
; 包括创建套接字，连接至服务器，发送登陆指令：用户名和密码,开启新线程接收消息
; 如果成功登录，eax=1；否则为0
;---------------------------------------------------------------
    LOCAL @stWsa:WSADATA  
    LOCAL @szBuffer[256]:byte
    LOCAL @stSin:sockaddr_in

    invoke WSAStartup,101h,addr @stWsa
    ; 创建流套接字，存入connSocket
    invoke socket,AF_INET,SOCK_STREAM,0
    ; 如果创建套接字失败，弹出消息框
    .if eax == INVALID_SOCKET
        invoke MessageBox,NULL,addr szErrSocket,addr szErrSocket,MB_OK
        mov eax,0
        ret
    .endif
    mov connSocket,eax

    ; 连接至服务器
    invoke RtlZeroMemory,addr @stSin,sizeof @stSin
    ; 转换ip
    invoke inet_addr,offset szAddr
    mov @stSin.sin_addr,eax   
    invoke htons,serverPort
    mov @stSin.sin_port,ax
    mov @stSin.sin_family,AF_INET
    invoke connect,connSocket,addr @stSin,sizeof @stSin
    ; 如果连接出现错误，弹出对话框
    .if eax == SOCKET_ERROR
        invoke WSAGetLastError
        .if eax != WSAEWOULDBLOCK
            invoke closesocket,connSocket;关闭套接字
            mov connSocket,0
            invoke MessageBox,NULL,addr szErrConnect,addr szErrConnect,MB_OK
            mov eax,0
            ret
        .endif
    .endif

    invoke send,connSocket,addr signal_login,1, 0
	
	invoke RtlZeroMemory,addr @szBuffer,sizeof @szBuffer
	invoke recv,connSocket,addr @szBuffer,sizeof @szBuffer,0
    invoke crt_strlen,username
	invoke send,connSocket,username,eax,0
	
	invoke RtlZeroMemory,addr @szBuffer,sizeof @szBuffer
	invoke recv,connSocket,addr @szBuffer,sizeof @szBuffer,0
    invoke crt_strlen,password
	invoke send,connSocket,password,eax,0
	
	invoke RtlZeroMemory,addr @szBuffer,sizeof @szBuffer
	invoke recv,connSocket,addr @szBuffer,sizeof @szBuffer,0
	;invoke CloseHandle,stdInHandle
	;.if eax == SOCKET_ERROR
	;invoke MessageBox,NULL,addr szErrSocket,addr szErrSocket,MB_OK
	;.endif
	invoke RtlZeroMemory,addr @szBuffer,sizeof @szBuffer
	invoke recv,connSocket,addr @szBuffer,sizeof @szBuffer,0

    
    ;如果返回消息成功
    .if @szBuffer[0]=='s'
        ;mov send_buffer,alloc(bufferSize)
        invoke crt_malloc,bufferSize
        mov send_buffer,eax
		;创建一个新线程监听服务器消息传入
		invoke CreateThread,NULL,0,offset chat_recvmsg,connSocket,NULL,esp
		invoke CloseHandle,eax
    .else		
        invoke closesocket,connSocket
        mov eax,0
        ret
    .endif
   
    mov eax,1
    ret

chat_login ENDP



;---------------------------------------------------------------
chat_sign_in PROC username:PTR BYTE,password:PTR BYTE
; 包括创建套接字，连接至服务器，发送注册指令：用户名和密码,关闭套接字
; 如果成功注册，eax=1；否则为0
;---------------------------------------------------------------
    LOCAL @stWsa:WSADATA  
    LOCAL @szBuffer[256]:byte
    LOCAL @stSin:sockaddr_in
    invoke WSAStartup,101h,addr @stWsa
    ; 创建流套接字，存入connSocket
    invoke socket,AF_INET,SOCK_STREAM,0
    ; 如果创建套接字失败，弹出消息框
    .if eax == INVALID_SOCKET
        invoke MessageBox,NULL,addr szErrSocket,addr szErrSocket,MB_OK
        mov eax,0
        ret
    .endif
    mov connSocket,eax

    ; 连接至服务器
    invoke RtlZeroMemory,addr @stSin,sizeof @stSin
    ; 转换ip
    invoke inet_addr,offset szAddr
    mov @stSin.sin_addr,eax   
    invoke htons,serverPort
    mov @stSin.sin_port,ax
    mov @stSin.sin_family,AF_INET
    invoke connect,connSocket,addr @stSin,sizeof @stSin
    ; 如果连接出现错误，弹出对话框
    .if eax == SOCKET_ERROR
        invoke WSAGetLastError
        .if eax != WSAEWOULDBLOCK
            invoke closesocket,connSocket;关闭套接字
            mov connSocket,0
            invoke MessageBox,NULL,addr szErrConnect,addr szErrConnect,MB_OK
            mov eax,0
            ret
        .endif
    .endif

    invoke send,connSocket,addr signal_signin,1,0
    invoke RtlZeroMemory,addr @szBuffer,sizeof @szBuffer
	invoke recv,connSocket,addr @szBuffer,sizeof @szBuffer,0
    invoke crt_strlen,username
	invoke send,connSocket,username,eax,0
    invoke RtlZeroMemory,addr @szBuffer,sizeof @szBuffer
	invoke recv,connSocket,addr @szBuffer,sizeof @szBuffer,0
    invoke crt_strlen,password
	invoke send,connSocket,password,eax,0
    invoke RtlZeroMemory,addr @szBuffer,sizeof @szBuffer
	invoke recv,connSocket,addr @szBuffer,sizeof @szBuffer,0
	;invoke CloseHandle,stdInHandle
	;.if eax == SOCKET_ERROR
	;invoke MessageBox,NULL,addr szErrSocket,addr szErrSocket,MB_OK
	;.endif

	invoke RtlZeroMemory,addr @szBuffer,sizeof @szBuffer
	invoke recv,connSocket,addr @szBuffer,sizeof @szBuffer,0


    ;如果返回消息不成功
    .if @szBuffer[0]!='s'	
        invoke closesocket,connSocket
        mov eax,0
        ret
    .endif

    invoke closesocket,connSocket  

    mov eax,1
    ret

chat_sign_in ENDP



;------------------------------------------------------------------------------
chat_sendmsg PROC username:PTR BYTE,sendmsg:PTR BYTE
; 用户发送消息,传入发送消息的对象用户名，和发送的消息: 比如 1 xiaohong xxxxxxxxx
; 发送成功，eax=1
;------------------------------------------------------------------------------

	invoke RtlZeroMemory,send_buffer,bufferSize
    invoke crt_strcpy,addr signal_sendtext,send_buffer
    invoke crt_strcat,send_buffer, username
    invoke crt_strcat,send_buffer,addr signal_tab
    invoke crt_strcat,send_buffer,sendmsg	

    invoke crt_strlen,send_buffer
	invoke send,connSocket,send_buffer,eax,0
;invoke send,connSocket,addr hint_connect,eax,0
    mov eax,1

    ret

chat_sendmsg ENDP



;------------------------------------------------------------------------------
chat_addFriend PROC username:PTR BYTE
; 用户点击按钮添加好友
; 发送指令： 2 xiaohong 
; 发送请求成功，eax=1；否则为0
;------------------------------------------------------------------------------

    LOCAL @szBuffer[100]:byte

	invoke RtlZeroMemory,addr @szBuffer,sizeof @szBuffer
    invoke crt_strcpy,addr signal_addfriend,addr @szBuffer
    invoke crt_strcat,addr @szBuffer,username
    invoke crt_strlen,addr @szBuffer
	invoke send,connSocket,addr @szBuffer,eax,0
    mov eax,1
    ret

chat_addFriend ENDP

END