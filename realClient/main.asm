.386
.model flat,stdcall
option casemap:none

include windows.inc
include gdi32.inc
include user32.inc
include kernel32.inc
include comctl32.inc
include msvcrt.inc
include ole32.inc
include header.inc
include comdlg32.inc

includelib gdi32.lib
includelib user32.lib
includelib kernel32.lib
includelib comctl32.lib
includelib msvcrt.lib
includelib ole32.lib
includelib comdlg32.lib

public hWinMain

;-----------------------------------------------------
;数据设置
;----------------------------------------------------
.data
hWinMain DD ?
hInstance DD ?
hToolBar DD ?
hAddrInput DD ?
hPortInput DD ?
hUsernameInput DD ?
hPasswordInput DD ?
hLogonButton DD ?
hLoginButton DD ?
hConnectButton DD ?
hReturnToHallButton DD ?
hAddFriendInput DD ?
hAddFriendButton DD ?
hDeleteFriendInput DD ?
hDeleteFriendButton DD ?
hFriendList DD ?
hOnlineUserList DD ?
hChatRoom DD ?
hMessageEditor DD ?
hMessageFormatTextColor DD ?
hMessageFormatEffects DD ?
hMessageFormatFacename DD ?
hMessageFormatBoldButton DD ?
hMessageFormatItalicsButton DD ?
hMessageFormatUnderlineButton DD ?
hMessageFormatStrikeoutButton DD ?
hMessageFormatTextFont DD ?
szBufIndex DWORD ?
szTextFont LOGFONT <?>
szBuffer dd 0
hMessageFormatWeight DD ?
hMessageFormatHeight DD ?
hMessageEditorSendButton DD ?
hMessageEditorClearButton DD ?
hCurrentChatRoomNameEdit DD ?
hStatusBar DD ?

ptrBuffer db 0

UsersNodeList DD 0 ;用来存放User的链表
currentUser DD 0 ; 当前对话的User， 如果为0表示当前在大厅
User struct
	username DD 0
	status DD 0 ; 上线或下线
	ID DD 0
	nextPtr dd 0 ; 指向下一个链表节点的指针
	hChatRoom dd 0 ; 此用户对应的聊天显示框
User ENDS

FORMAT_INT db '%d',0

curOnlineListRow DD -1
curFriendListRow DD -1

ptrUsername DD 0
ptrUsers dd 0

.const
szClientWindowClassName DB "Client Window",0 ; ClientWindow 的类名
szClientWindowName DB "Client",0 ; ClientWindow的窗口标题名称
;bufSize = 104857600
szOle32 db 'ole32.dll', 0
szMsftedit db 'Msftedit.dll', 0
szStatic db 'STATIC',0
szButton db 'BUTTON',0
szAddress db 'ADDRESS',0
szPort db 'PORT',0
szUsername db 'USERNAME',0
szLogin db 'LOGIN',0
szLogon db 'LOGON',0
szEdit db 'EDIT',0
szSend db 'SEND',0
szClear db 'CLEAR',0
szListView db 'SysListView32',0
szRichEdit50W db 'RICHEDIT50W',0
szStatus db 'STATUS',0
szAllOnlineUsers db 'all online users',0
szFriends db 'friends',0
szOnline db 'online',0
szOffline db 'offline',0
szMe db 'Me',0
szColon db ' : ',0
szNewLine db 0dh, 0ah,0
szPadding db 'padding',0
szApplyPass db 'apply pass',0
szApplyReject db 'apply reject',0
szDelete db 'delete',0
szReturnToHall db 'return to hall',0
szAddFriend db 'add friend', 0
szHallChatRoom db 'Hall ChatRoom',0
szDeleteFriend db 'delete friend',0
szPassword db 'PASSWORD',0
szBufSize = 16777216
szEnd db ' ', 0dh, 0ah, 0
szSpace db ' ', 0
szDash db '-', 0
szBold db 'B', 0
szItalics db 'I', 0
szUnderline db 'U', 0
szStrikeout db 'S', 0
szTextfont db 'Font', 0
szName db 'User', 0


LOGON_BUTTON_HANDLE				EQU 1
LOGIN_BUTTON_HANDLE				EQU 2
SEND_BUTTON_HANDLE				EQU 3
CLEAR_BUTTON_HANDLE				EQU 4
ADD_FRIEND_BUTTON_HANDLE		EQU 5
RETURN_TO_HALL_BUTTON_HANDLE	EQU 6
DELETE_FRIEND_BUTTON_HANDLE		EQU 7
BOLD_BUTTON_HANDLE			    EQU 8
ITALICS_BUTTON_HANDLE			EQU 9
UNDERLINE_BUTTON_HANDLE			EQU 10
STRIKEOUT_BUTTON_HANDLE			EQU 11
TEXTFONT_BUTTON_HANDLE			EQU 12
.code
;----------------------------------------------------------
_createListView PROC USES eax esi
; 这里创建大厅list列表和好友list列表
;----------------------------------------------------------
	local @col:LVCOLUMN
	; 创建onlineUserlistview 句柄1
	invoke CreateWindowEx, NULL, offset szListView, NULL,\
	WS_CHILD or WS_BORDER or WS_VSCROLL or WS_VISIBLE or LVS_SINGLESEL or LVS_REPORT,\ ;添加了LVS_REPORT才能显示表头
	20, 80, 300, 250,\
	hWinMain, 1, hInstance, NULL
	mov hOnlineUserList, eax

	; 设置onlineUserListView的表头
	; 第一列 用户名 Username
	mov @col.imask, LVCF_TEXT or LVCF_WIDTH ; 这里是在设置col的什么属性是可用的
	mov @col.lx, 180
	mov @col.pszText, offset szUsername
	invoke SendMessage, hOnlineUserList, LVM_INSERTCOLUMN, 0, addr @col
	; 第二列 用户状态 status （是否在线）
	mov @col.imask, LVCF_TEXT or LVCF_WIDTH
	mov @col.lx, 120
	mov @col.pszText, offset szStatus
	invoke SendMessage, hOnlineUserList, LVM_INSERTCOLUMN, 1, addr @col

	invoke SendMessage, hOnlineUserList, LVM_SETEXTENDEDLISTVIEWSTYLE, 0, LVS_EX_FULLROWSELECT or LVS_EX_AUTOSIZECOLUMNS

	; 创建friendListView 句柄2
	invoke CreateWindowEx, NULL, offset szListView, NULL,\
	WS_CHILD or WS_BORDER or WS_VSCROLL or WS_VISIBLE or LVS_SINGLESEL or LVS_REPORT,\
	20, 380, 300, 280,\
	hWinMain, 2, hInstance, NULL
	mov hFriendList, eax

	; 设置FriendListView的表头
	; 第一列 用户名 Username
	mov @col.imask, LVCF_TEXT or LVCF_WIDTH; 这里是在设置col的什么属性是可用的
	mov @col.lx, 180
	mov @col.pszText, offset szUsername
	invoke SendMessage, hFriendList, LVM_INSERTCOLUMN, 0, addr @col
	; 第二列 用户状态 status （是否在线）
	mov @col.imask, LVCF_TEXT or LVCF_WIDTH
	mov @col.lx, 120
	mov @col.pszText, offset szStatus
	invoke SendMessage, hFriendList, LVM_INSERTCOLUMN, 1, addr @col

	invoke SendMessage, hFriendList, LVM_SETEXTENDEDLISTVIEWSTYLE, 0, LVS_EX_FULLROWSELECT or LVS_EX_AUTOSIZECOLUMNS
	ret
_createListView ENDP

_ClearEditor PROC
	invoke SetWindowText,hMessageEditor, NULL
	ret
_ClearEditor ENDP

_SetRealCb PROC USES esi edi dwB:DWORD, lpB:DWORD
	mov esi, lpB
	mov edi, dwB
	mov [esi], edi
	ret
_SetRealCb ENDP

_GetStreamWork PROC StreamType:DWORD, StreamHandle:DWORD
	local @Message:EDITSTREAM
	local @BufIndex:DWORD
	mov eax, szBuffer
	mov @BufIndex, eax
	lea eax, @BufIndex
	mov szBufIndex, eax
	.if StreamType == 0
		mov @Message.dwCookie, TRUE
		mov @Message.pfnCallback, offset _ProcMessageStream
		invoke SendMessage,StreamHandle,EM_STREAMOUT,SF_RTF,addr @Message
	.else
		mov @Message.dwCookie, FALSE
		mov @Message.pfnCallback, offset _ProcMessageStream
		invoke SendMessage, StreamHandle, EM_STREAMIN, SF_RTF or SFF_SELECTION, addr @Message
	.endif
	ret
_GetStreamWork ENDP

_ShowMessage PROC USES eax edx esi Message:DWORD, IsHall:DWORD, Username:DWORD, IsMe:DWORD
	local @CharPlace:CHARRANGE
	local @SenderFormat:CHARFORMAT2
	local @TimeFormat:CHARFORMAT2
	local @MessageIn:EDITSTREAM
	local @CurrentTime:SYSTEMTIME
	local @ChatRoomHandle:DWORD
	invoke	RtlZeroMemory,addr @SenderFormat,sizeof @SenderFormat
	mov	@SenderFormat.cbSize,sizeof @SenderFormat
	mov @SenderFormat.yHeight, 180
	mov @SenderFormat.dwEffects, CFE_BOLD
	.if IsHall == 1
		.if IsMe == 1
			mov @SenderFormat.crTextColor, 0d01040h
		.else
			mov @SenderFormat.crTextColor, 02170edh
		.endif
	.else
		.if IsMe == 1
			mov @SenderFormat.crTextColor, 0d01040h
		.else
			mov @SenderFormat.crTextColor, 0c91dfch
		.endif
	.endif
	mov @SenderFormat.dwMask, CFM_COLOR or CFM_SIZE or CFM_BOLD
	.if IsHall == 1
		mov eax, hChatRoom
		mov @ChatRoomHandle, eax
	.else
		mov esi, UsersNodeList
		.while esi != 0
			mov edi, (User ptr [esi]).username
			invoke crt_strcmp, Username, edi
			.if eax == 0
				.break
			.endif
			mov esi, (User ptr [esi]).nextPtr
		.endw
		mov eax, (User ptr [esi]).hChatRoom
		mov @ChatRoomHandle, eax
	.endif
	invoke RtlZeroMemory,addr @CharPlace,sizeof @CharPlace
	mov @CharPlace.cpMin, -1
	mov @CharPlace.cpMax, -1
	invoke SendMessage, @ChatRoomHandle, EM_EXSETSEL, 0, addr @CharPlace
	.if IsMe == 0
		invoke SendMessage, @ChatRoomHandle, EM_SETCHARFORMAT, SCF_SELECTION, addr @SenderFormat
		invoke SendMessage, @ChatRoomHandle, EM_REPLACESEL, 1, Username
	.else
		invoke SendMessage, @ChatRoomHandle, EM_SETCHARFORMAT, SCF_SELECTION, addr @SenderFormat
		invoke SendMessage, @ChatRoomHandle, EM_REPLACESEL, 1, addr szMe
	.endif
	invoke GetLocalTime, addr @CurrentTime
	;invoke printf, addr debugMsg, @CurrentTime.wYear, @CurrentTime.wMonth
	;invoke SendMessage, @ChatRoomHandle, EM_REPLACESEL, 1, @CurrentTime.wYear
	invoke SendMessage, @ChatRoomHandle, EM_REPLACESEL, 1, addr szEnd
	invoke _GetStreamWork, 1, @ChatRoomHandle
	ret
_ShowMessage ENDP

_SendMessage PROC USES eax esi edi
	invoke _GetStreamWork, 0, hMessageEditor
	invoke _ClearEditor
	invoke _ShowMessage, szBuffer, 1, addr szName, 1
	ret
_SendMessage ENDP

_ProcMessageStream PROC uses edi esi edx _dwCookie,_lpBuffer,_dwBytes,_lpBytes
	mov edi, szBufIndex
	mov edx, _dwBytes
	mov esi, [edi]
	.if _dwCookie
		invoke crt_memcpy, esi, _lpBuffer, edx
	.else
		invoke crt_memcpy, _lpBuffer, esi, edx
	.endif
	add esi,_dwBytes
	mov [edi], esi
	invoke _SetRealCb, _dwBytes, _lpBytes 
	xor	eax,eax
	ret
_ProcMessageStream ENDP

_SetCharEffect PROC EffectType:DWORD
	local @CharSelected:CHARRANGE
	local @CharFormat:CHARFORMAT2
	invoke SendMessage,hMessageEditor,EM_EXGETSEL,0,addr @CharSelected
	mov eax,@CharSelected.cpMin
	.if eax !=	@CharSelected.cpMax
		invoke	RtlZeroMemory,addr @CharFormat,sizeof @CharFormat
		mov	@CharFormat.cbSize,sizeof @CharFormat
		.if EffectType == 0
			mov @CharFormat.dwEffects, CFE_BOLD
			mov	@CharFormat.dwMask,CFM_BOLD
		.elseif EffectType == 1
			mov @CharFormat.dwEffects, CFE_ITALIC
			mov	@CharFormat.dwMask,CFE_ITALIC
		.elseif EffectType == 2
			mov @CharFormat.dwEffects, CFE_UNDERLINE
			mov	@CharFormat.dwMask,CFE_UNDERLINE
		.elseif EffectType == 3
			mov @CharFormat.dwEffects, CFE_STRIKEOUT
			mov	@CharFormat.dwMask,CFE_STRIKEOUT
		.endif
		invoke SendMessage,hMessageEditor,EM_SETCHARFORMAT,SCF_SELECTION,addr @CharFormat
	.endif
	ret
_SetCharEffect ENDP

_SetCharFont PROC USES eax edi
	local @FontSelected:CHOOSEFONT
	local @CharFormat:CHARFORMAT2
	local @TextColor:DWORD
	local @TextSize:DWORD
	local @TextFaceName:DWORD
	invoke	RtlZeroMemory,addr @FontSelected,sizeof @FontSelected
	mov	@FontSelected.lStructSize,sizeof @FontSelected
	push hWinMain
	pop @FontSelected.hwndOwner
	mov	@FontSelected.lpLogFont,offset szTextFont
	mov	@FontSelected.Flags,CF_SCREENFONTS or CF_EFFECTS
	invoke ChooseFont,addr @FontSelected
	.if	eax
		invoke	RtlZeroMemory,addr @CharFormat,sizeof @CharFormat
		mov	@CharFormat.cbSize,sizeof @CharFormat
		mov	@CharFormat.dwMask,CFM_SIZE or CFM_FACE or CFM_BOLD or CFE_ITALIC or CFE_UNDERLINE or CFE_STRIKEOUT or CFM_COLOR
		push @FontSelected.rgbColors
		pop @CharFormat.crTextColor
		mov	eax,@FontSelected.iPointSize
		shl	eax,1
		mov @TextSize, eax
		push @TextSize
		pop @CharFormat.yHeight
		invoke lstrcpy,addr @CharFormat.szFaceName, addr szTextFont.lfFaceName
		invoke SendMessage,hMessageEditor,EM_SETCHARFORMAT,SCF_SELECTION,addr @CharFormat
	.endif
	ret
_SetCharFont ENDP

;-----------------------------------------------------------------
_getUsernameByRow PROC USES eax esi edi, row:DWORD, hListView:DWORD
; 通过行数得到用户名，并存在全局变量 ptrUsername中
;----------------------------------------------------------------
	local @username:DWORD
	local @buffer[128]:DWORD
	local @item :LV_ITEM

	mov @item.iSubItem, 0
	lea eax, @buffer
	mov @item.pszText, eax
	mov @item.cchTextMax, 128
	invoke SendMessage, hListView, LVM_GETITEMTEXT, row, addr @item
	mov eax, @item.pszText
	invoke crt_strcpy, addr ptrUsername, eax

	ret
_getUsernameByRow ENDP
;-----------------------------------------------------------------
_addUserToList PROC USES eax ebx esi edi, username:DWORD, status:DWORD, hListView:DWORD
; 将用户加入列表中
;-----------------------------------------------------------------
	local @item: LVITEM
	local @hChatRoom: DWORD

	;invoke crt_printf, username
	; 写入username
	mov @item.imask, LVIF_TEXT
	mov @item.pszText, NULL
	invoke crt_printf, username
	invoke SendMessage, hListView, LVM_GETITEMCOUNT, 0, 0
	mov @item.iItem, eax
	mov @item.iSubItem, 0
	invoke SendMessage, hListView, LVM_INSERTITEM, 0, addr @item
	
	mov eax, username
	mov @item.pszText, eax
	invoke SendMessage, hListView, LVM_SETITEM, 0, addr @item
	; 写入用户状态
	.if status == 1
		mov eax, offset szOnline
	.elseif status ==2
		mov eax, offset szOffline
	.elseif status == 3
		mov eax, offset szPadding
	.elseif status == 4
		mov eax, offset szApplyPass
	.elseif status == 5
		mov eax, offset szApplyReject
	.elseif status == 6
		mov eax, offset szDelete
	.endif
	mov @item.pszText,eax
	add @item.iSubItem, 1
	invoke SendMessage, hListView, LVM_SETITEM, 0, addr @item

	; 如果是加入大厅列表，不需要建立User结构体以及加入User链表
	mov eax, hOnlineUserList
	cmp hListView,eax
	je QUIT

	; 新建User结构体，写入Username和status
	invoke GlobalAlloc, GPTR, sizeof User
	mov edi, eax
	invoke crt_malloc, 48
	mov (User ptr [edi]).username, eax
	invoke crt_strcpy, (User ptr [edi]).username, username

	;invoke crt_malloc, 48
	;mov (User ptr [edi]).status, eax
	;invoke crt_strcpy, (User ptr [edi]).status, status
	mov eax, status
	mov (User ptr [edi]).status, eax

	; 创建属于该用户的聊天显示框，并绑定在User结构体中
	invoke CreateWindowEx, NULL, addr szRichEdit50W, NULL,\
	WS_CHILD or WS_VISIBLE or WS_BORDER or WS_VSCROLL or ES_LEFT or ES_MULTILINE or ES_AUTOVSCROLL or ES_READONLY,\
	350, 80, 860, 360,\
	hWinMain, 0, hInstance, NULL
	mov (User ptr [edi]).hChatRoom, eax

	; 将该User结构体插入链表中
	.if UsersNodeList == 0
		mov UsersNodeList, edi
	.else
		mov esi, UsersNodeList
		mov ebx, (User ptr [esi]).nextPtr
		.while ebx != 0
			mov esi,ebx
			mov ebx, (User ptr [esi]).nextPtr
		.endw
		mov (User ptr [esi]).nextPtr, edi
		mov (User ptr [edi]).nextPtr, 0
	.endif
QUIT:
	ret

_addUserToList ENDP

;-------------------------------------------------------------
_streamWriteCallBack PROC USES eax ebx edi esi dwCookie:DWORD, lpBuffer:DWORD, dwBytes:DWORD, lpBytes:DWORD
; 文本流输入要求的回调函数，在下面的addMsg中使用
; dwCookie中存储着需要传输的文本,将其写入lpBuffer中，dwBytes表示写入的文本长度，lpBytes表示实际写入的文本长度
;-------------------------------------------------------------
	mov edi, dwCookie
	mov esi, [edi]
	invoke crt_memcpy, lpBuffer, esi, dwBytes
	add esi, dwBytes
	mov [edi], esi
	mov esi, lpBytes
	mov edi, dwBytes
	mov [esi], edi
	mov eax, 0
	ret
_streamWriteCallBack ENDP

;-----------------------------------------------------------
_addMsg PROC USES eax edx esi edi, username:DWORD, msg:DWORD, sender:DWORD, sendTo:DWORD
; 该函数将传入的msg放置到当前的聊天显示框上
; sender 表示发送人，1是对面，0是自己
; sendTo 表示发送目的地，0是大厅，1是好友
;-----------------------------------------------------------
	local @hChatRoom: DWORD
	local @charRange: CHARRANGE
	local @editStream: EDITSTREAM
	local @ptr: DWORD
	.if sendTo == 1
		; 在USER链表中找到对应的用户，找到他的聊天显示框
		mov esi, UsersNodeList
		.while esi != 0
			mov edi , (User ptr [esi]).username
			invoke crt_strcmp, edi, username
			.if eax == 0
				.break
			.endif
			mov esi, (User ptr [esi]).nextPtr
		.endw
		mov eax, (User ptr [esi]).hChatRoom
		mov @hChatRoom, eax
	.else
		mov eax, hChatRoom
		mov @hChatRoom, eax
	.endif

	invoke SendMessage, @hChatRoom, EM_SETSEL, -1, -1 ;设定文本插入范围，-1表示文本末尾
	;invoke SendMessage, @hChatRoom, EM_EXGETSEL, 0, addr @charRange ; 获取文本选择范围，可以通过这个来改变样式

	; 判断发送方是谁，1是对面，0是自己
	.if sender == 1
		; TODO 设置富文本样式
		invoke SendMessage, @hChatRoom, EM_REPLACESEL, 1, username
	.else 
		; TODO 设置富文本样式
		invoke SendMessage, @hChatRoom, EM_REPLACESEL, 1, addr szMe
	.endif

	invoke SendMessage, @hChatRoom, EM_REPLACESEL, 1, addr szColon ; 用户名后加个冒号

	invoke SendMessage, @hChatRoom, EM_REPLACESEL, 1, addr szNewLine ; 换行

	; 写入文本，为了支持图片，甚至文件传输，需要使用文本流（Text Streaming）
	mov @editStream.pfnCallback, offset _streamWriteCallBack
	mov eax, msg
	mov @ptr, eax
	lea eax, @ptr
	mov @editStream.dwCookie, eax
	mov @editStream.dwError, 1
	invoke SendMessage, @hChatRoom, EM_STREAMIN, SF_RTF or SFF_SELECTION, addr @editStream

	invoke SendMessage, @hChatRoom, EM_REPLACESEL, 1, addr szNewLine ; 换行
	ret
_addMsg ENDP

;----------------------------------------------------------
_changeFriendStatus PROC USES eax ecx esi, username:DWORD, status:DWORD
; 改变朋友的状态
;----------------------------------------------------------
	local @item: LVITEM
	local @row: DWORD
	; 遍历User链表，找出对应User
	mov @row, 0	; 利用@row计数，得到对应user行数
	mov esi, UsersNodeList
	.while esi != 0
		invoke crt_strcmp, (User ptr [esi]).username, username
		.if eax == 0
			.break
		.endif
		inc @row
		mov esi, (User ptr [esi]).nextPtr
	.endw
	.if esi == 0
		jmp QUIT
	.endif

	mov eax, status
	mov (User ptr [esi]).status, eax

	mov @item.imask, LVIF_TEXT
	mov @item.iSubItem, 1
	.if status == 1
		mov eax, offset szOnline
	.elseif status ==2
		mov eax, offset szOffline
	.elseif status == 3
		mov eax, offset szPadding
	.elseif status == 4
		mov eax, offset szApplyPass
	.elseif status == 5
		mov eax, offset szApplyReject
	.elseif status == 6
		mov eax, offset szDelete
	.endif
	mov @item.pszText, eax
	invoke SendMessage, hFriendList, LVM_SETITEMTEXT, @row, addr @item
QUIT:
	ret
_changeFriendStatus ENDP

;-------------------------------------------------------------------------
_deleteUserFromList PROC USES eax ebx esi edi, username:DWORD, hListView:DWORD
; 将给定username的用户从给定的listview中删除
;--------------------------------------------------------------------------
	local @item: LV_ITEM
	local @row: DWORD
	local @lastPtr: DWORD
	local @rowCount: DWORD
	local @buffer[128]: DWORD
	; 遍历User链表，找出对应User
	mov @row, 0	; 利用@row计数，得到对应user行数

	; 如果操作对象ListView是大厅，跳过从链表中删除的步骤
	mov eax, hListView
	cmp eax, hOnlineUserList
	je L1

	; 如果删除的是链表头，直接将链表头向后移位
	mov esi, UsersNodeList
	invoke crt_strcmp, (User ptr [esi]).username, username
	.if eax == 0
		mov ebx, (User ptr [esi]).nextPtr
		mov UsersNodeList, ebx
		jmp L1
	.endif

	; 开始遍历链表找到目标
	mov @lastPtr, esi
	.while esi != 0
		invoke crt_strcmp, (User ptr [esi]).username, username
		.if eax == 0
			mov edi, @lastPtr
			mov ebx,  (User ptr [esi]).nextPtr
			mov (User ptr [edi]).nextPtr, ebx
			.break
		.endif
		inc @row
		mov @lastPtr, esi
		mov esi, (User ptr [esi]).nextPtr
	.endw

L1:
	; 接下来将用户从ListView中删除
	mov @row, 0
	invoke SendMessage, hListView, LVM_GETITEMCOUNT, 0, 0
	mov @rowCount, eax
	mov @item.iSubItem, 0
	mov @item.cchTextMax, 128
	lea eax, @buffer
	mov @item.pszText, eax
	mov ebx, @rowCount
	.while @row != ebx
		invoke SendMessage, hListView, LVM_GETITEMTEXT, @row, addr @item
		invoke crt_strcmp, @item.pszText , username
		.if eax == 0
			invoke SendMessage, hListView, LVM_DELETEITEM, @row, 0
			.break
		.endif
		inc @row
	.endw
	ret
_deleteUserFromList ENDP

;----------------------------------------------------------
_switchChatRoom PROC USES eax esi edi, row:DWORD, isHall:Byte
; 切换当前的聊天室，isHall == 1 表示切换到大厅，否则切换到对应的Username的聊天室
;----------------------------------------------------------
	local @item:LV_ITEM
	local @username:DWORD
	local @buffer[128]:DWORD
	; 如果切换到大厅,隐藏原来的窗口，赋值为0。
	.if isHall == 1
		mov edi, currentUser
		.if currentUser != 0
			invoke ShowWindow, (User ptr [edi]).hChatRoom, SW_HIDE
			mov currentUser, 0
		.endif
		invoke ShowWindow, hChatRoom, SW_SHOW
		jmp SetName
	.endif

	; 先通过row找到对应的username
	mov @item.iSubItem, 0
	lea eax, @buffer
	mov @item.pszText, eax
	mov @item.cchTextMax, 128
	invoke SendMessage, hFriendList, LVM_GETITEMTEXT, row, addr @item
	.if eax == 0 ; 找不到则退出
		jmp QUIT
	.endif
	mov esi, @item.pszText
	mov @username, esi


	mov esi, UsersNodeList
	.while esi != 0
		invoke crt_strcmp, @username, (User ptr [esi]).username
		.if eax == 0
			; 如果currentUser不为0，隐藏他的窗口
			mov edi, currentUser
			.if edi != 0
				invoke ShowWindow, (User ptr [edi]).hChatRoom, SW_HIDE
			.else 
				; 如果为0 隐藏大厅窗口
				invoke ShowWindow, hChatRoom, SW_HIDE
			.endif
			; 赋值
			mov currentUser, esi
			invoke ShowWindow, (User ptr [esi]).hChatRoom, SW_SHOW
			.break
		.endif
		mov esi, (User ptr [esi]).nextPtr
	.endw

	; 根据当前用户在线情况来决定send按钮是否可以按下
	mov esi, currentUser
	mov eax, (User ptr [esi]).status
	.if eax == 1
		invoke EnableWindow, hMessageEditorSendButton, 1
	.elseif eax == 4
		invoke EnableWindow, hMessageEditorSendButton, 1
	.else
		invoke EnableWindow, hMessageEditorSendButton, 0
	.endif

SetName:
	; 在某个地方显示当前对话的聊天室
	.if currentUser == 0
		invoke SendMessage, hCurrentChatRoomNameEdit, WM_SETTEXT, 0, addr szHallChatRoom
	.else
		mov esi, currentUser
		invoke SendMessage, hCurrentChatRoomNameEdit, WM_SETTEXT, 0, (User ptr [esi]).username
	.endif
		

QUIT:
	ret
_switchChatRoom ENDP

;---------------------------------------------------------
_connect PROC USES eax edx esi
; 获取IP 和 PORT输入框中的值，并连接server
; 参数正确则返回1， 否则返回0
;---------------------------------------------------------
	local @IP:DWORD
	local @PORT:DWORD

	;mov @IP[0], 128
	invoke GlobalAlloc, GPTR, 128
	mov @IP, eax
	invoke SendMessage, hAddrInput, WM_GETTEXT, 128, @IP

	invoke GlobalAlloc, GPTR, 128
	mov esi, eax
	invoke SendMessage, hAddrInput, WM_GETTEXT, 128, esi
	invoke crt_sscanf, esi, addr FORMAT_INT, addr @PORT
	; TODO 调用Client中的登陆函数
QUIT:
	ret
_connect ENDP

;--------------------------------------------------------
_logon PROC USES eax
; 获取用户名，并注册
;--------------------------------------------------------
	local @username:DWORD
	local @IP:DWORD
	local @PORT:DWORD
	local @password:DWORD

	;mov @IP[0], 128
	invoke GlobalAlloc, GPTR, 128
	mov @IP, eax
	invoke SendMessage, hAddrInput, WM_GETTEXT, 128, @IP

	invoke GlobalAlloc, GPTR, 128
	mov esi, eax
	invoke SendMessage, hPortInput, WM_GETTEXT, 128, esi
	invoke crt_sscanf, esi, addr FORMAT_INT, addr @PORT
	invoke GlobalAlloc, GPTR, 128
	mov @username, eax
	invoke SendMessage, hUsernameInput, WM_GETTEXT, 128, @username

	invoke GlobalAlloc, GPTR, 128
	mov @password, eax
	invoke SendMessage, hPasswordInput, WM_GETTEXT, 128, @password

	;TODO 向server发送注册请求
	invoke clientSignIn, @IP, @PORT, @username, @password
	ret
_logon ENDP

;--------------------------------------------------------
_login PROC USES eax
; 获取用户名，并登录
;--------------------------------------------------------
	local @username:DWORD
	local @IP:DWORD
	local @PORT:DWORD
	local @password:DWORD

	invoke GlobalAlloc, GPTR, 128
	mov @IP, eax
	invoke SendMessage, hAddrInput, WM_GETTEXT, 128, @IP

	invoke GlobalAlloc, GPTR, 128
	mov esi, eax
	invoke SendMessage, hPortInput, WM_GETTEXT, 128, esi
	invoke crt_sscanf, esi, addr FORMAT_INT, addr @PORT
	invoke GlobalAlloc, GPTR, 128
	mov @username, eax
	invoke SendMessage, hUsernameInput, WM_GETTEXT, 128, @username

	invoke GlobalAlloc, GPTR, 128
	mov @password, eax
	invoke SendMessage, hPasswordInput, WM_GETTEXT, 128, @password

	;TODO 向server发送注册请求
	invoke clientLogIn, @IP, @PORT, @username, @password
	ret
_login ENDP

;---------------------------------------------------------
_createUI PROC USES eax
; 这里是初始化窗口UI的函数, 在ClientWindowProc里调用（大概）
; 每个用户对应的聊天窗是动态创建的，不在这儿。
;----------------------------------------------------------
	; 创建登录栏

	; Address标签
	invoke CreateWindowEx, NULL, addr szStatic, addr szAddress, \
	WS_VISIBLE or WS_DISABLED or WS_CHILD, \
	20,20,80,20,\
	hWinMain, 0, hInstance, NULL
	;Address 输入框
	invoke CreateWindowEx, NULL, addr szEdit, NULL,\
	WS_TABSTOP or WS_CHILD or WS_VISIBLE or WS_BORDER,\
	90,20,150,20,\
	hWinMain, 0, hInstance, NULL
	mov hAddrInput, eax
	;invoke SendMessage, hNewEdit, WM_SETFONT, hFont, 0

	; PORT标签
	invoke CreateWindowEx, NULL, addr szStatic, addr szPort, \
	WS_VISIBLE or WS_DISABLED or WS_CHILD, \
	250,20,80,20,\
	hWinMain, 0, hInstance, NULL
	; PORT 输入框
	invoke CreateWindowEx, NULL, addr szEdit, NULL,\
	WS_TABSTOP or WS_CHILD or WS_VISIBLE or WS_BORDER,\
	290,20,150,20,\
	hWinMain, 0, hInstance, NULL
	mov hPortInput, eax

	; Username 标签
	invoke CreateWindowEx, NULL, addr szStatic, addr szUsername, \
	WS_VISIBLE or WS_DISABLED or WS_CHILD, \
	460,20,80,20,\
	hWinMain, 0, hInstance, NULL
	; Username 输入框
	invoke CreateWindowEx, NULL, addr szEdit, NULL,\
	WS_TABSTOP or WS_CHILD or WS_VISIBLE or WS_BORDER,\
	540,20,150,20,\
	hWinMain, 0, hInstance, NULL
	mov hUsernameInput, eax

	; Password 标签
	invoke CreateWindowEx, NULL, addr szStatic, addr szPassword, \
	WS_VISIBLE or WS_DISABLED or WS_CHILD, \
	700,20,80,20,\
	hWinMain, 0, hInstance, NULL
	; Password 输入框
	invoke CreateWindowEx, NULL, addr szEdit, NULL,\
	WS_TABSTOP or WS_CHILD or WS_VISIBLE or WS_BORDER,\
	780,20,150,20,\
	hWinMain, 0, hInstance, NULL
	mov hPasswordInput, eax

	; 当前聊天室名称展示框
	invoke CreateWindowEx, NULL, addr szEdit, NULL,\
	WS_TABSTOP or WS_CHILD or WS_VISIBLE or WS_BORDER,\
	350,50,150,20,\
	hWinMain, 0, hInstance, NULL
	mov hCurrentChatRoomNameEdit, eax

	; login按钮 句柄1
	invoke CreateWindowEx, NULL, addr szButton, addr szLogin, \
	WS_VISIBLE or WS_CHILD, \
	710,50,60,20,\
	hWinMain, LOGIN_BUTTON_HANDLE, hInstance, NULL
	mov hLoginButton, eax
	;invoke EnableWindow, hSendButton, 0
	;invoke SendMessage, hSendButton, WM_SETFONT, hFont, 0

	; logon按钮 句柄2
	invoke CreateWindowEx, NULL, addr szButton, addr szLogon, \
	WS_VISIBLE or WS_CHILD, \
	800,50,60,20,\
	hWinMain, LOGON_BUTTON_HANDLE, hInstance, NULL
	mov hLogonButton, eax
	;invoke EnableWindow, hSendButton, 0
	;invoke SendMessage, hSendButton, WM_SETFONT, hFont, 0

	; send按钮 句柄3
	invoke CreateWindowEx, NULL, addr szButton, addr szSend, \
	WS_VISIBLE or WS_CHILD, \
	1100,620,100,40,\
	hWinMain, SEND_BUTTON_HANDLE, hInstance, NULL
	mov hMessageEditorSendButton, eax

	; clear按钮 句柄4
	invoke CreateWindowEx, NULL, addr szButton, addr szClear, \
	WS_VISIBLE or WS_CHILD, \
	960,620,100,40,\
	hWinMain, CLEAR_BUTTON_HANDLE, hInstance, NULL
	mov hMessageEditorClearButton, eax

	; addFriend按钮 句柄5
	invoke CreateWindowEx, NULL, addr szButton, addr szAddFriend, \
	WS_VISIBLE or WS_CHILD, \
	20,45,100,30,\
	hWinMain, ADD_FRIEND_BUTTON_HANDLE, hInstance, NULL
	mov hAddFriendButton, eax

	; return to hall 按钮 句柄6
	invoke CreateWindowEx, NULL, addr szButton, addr szReturnToHall, \
	WS_VISIBLE or WS_CHILD, \
	150,45,100,30,\
	hWinMain, RETURN_TO_HALL_BUTTON_HANDLE, hInstance, NULL
	mov hReturnToHallButton, eax

	; delete friend 按钮 句柄7
	invoke CreateWindowEx, NULL, addr szButton, addr szDeleteFriend, \
	WS_VISIBLE or WS_CHILD, \
	20,340,100,30,\
	hWinMain, DELETE_FRIEND_BUTTON_HANDLE, hInstance, NULL
	mov hDeleteFriendButton, eax

	; 创建聊天显示框
	invoke CreateWindowEx, NULL, addr szRichEdit50W, NULL,\
	WS_CHILD or WS_VISIBLE or WS_BORDER or WS_VSCROLL or ES_LEFT or ES_MULTILINE or ES_AUTOVSCROLL,\
	350, 80, 860, 360,\
	hWinMain, 0, hInstance, NULL
	mov hChatRoom, eax

	; 创建聊天输入框
	invoke CreateWindowEx, NULL, addr szRichEdit50W, NULL,\
	WS_CHILD or WS_VISIBLE or WS_BORDER or WS_VSCROLL or ES_LEFT or ES_MULTILINE or ES_AUTOVSCROLL,\
	350, 500, 860, 100,\
	hWinMain, 0, hInstance, NULL
	mov hMessageEditor, eax
	invoke crt_malloc, szBufSize
	mov szBuffer, eax

	; Bold Button handle 8
	invoke CreateWindowEx, NULL, addr szButton, addr szBold, \
	WS_VISIBLE or WS_CHILD or BS_FLAT or WS_EX_TRANSPARENT, \
	350,465,30,30,\
	hWinMain, BOLD_BUTTON_HANDLE, hInstance, NULL
	mov hMessageFormatBoldButton, eax

	; Italics Button handle 9
	invoke CreateWindowEx, NULL, addr szButton, addr szItalics, \
	WS_VISIBLE or WS_CHILD or BS_FLAT or WS_EX_TRANSPARENT, \
	380,465,30,30,\
	hWinMain, ITALICS_BUTTON_HANDLE, hInstance, NULL
	mov hMessageFormatItalicsButton, eax

	; Underline Button handle 10
	invoke CreateWindowEx, NULL, addr szButton, addr szUnderline, \
	WS_VISIBLE or WS_CHILD or BS_FLAT or WS_EX_TRANSPARENT, \
	410,465,30,30,\
	hWinMain, UNDERLINE_BUTTON_HANDLE, hInstance, NULL
	mov hMessageFormatUnderlineButton, eax

	; Strikeout Button handle 11
	invoke CreateWindowEx, NULL, addr szButton, addr szStrikeout, \
	WS_VISIBLE or WS_CHILD or BS_FLAT or WS_EX_TRANSPARENT, \
	440,465,30,30,\
	hWinMain, STRIKEOUT_BUTTON_HANDLE, hInstance, NULL
	mov hMessageFormatStrikeoutButton, eax

	; Textfont Button handle 12
	invoke CreateWindowEx, NULL, addr szButton, addr szTextfont, \
	WS_VISIBLE or WS_CHILD or BS_FLAT or WS_EX_TRANSPARENT, \
	470,465,40,30,\
	hWinMain, TEXTFONT_BUTTON_HANDLE, hInstance, NULL
	mov hMessageFormatTextFont, eax

	; 创建大厅用户列表，好友列表（调用_createListView函数）
	invoke _createListView
	ret
_createUI ENDP

;----------------------------------------------------------
_ClientWindowProc PROC USES ebx esi edi, hWnd:DWORD, uMsg:DWORD, wParam:DWORD, lParam:DWORD
; 主窗口过程
;----------------------------------------------------------
	local @stPs:PAINTSTRUCT
	local @stRect:RECT
	local @hDc
	local @username :DWORD

	mov eax, uMsg

	.if eax == WM_CLOSE
		invoke DestroyWindow, hWinMain
		invoke PostQuitMessage, NULL
	.elseif eax == WM_CREATE ; 窗口初始化
		mov eax, hWnd
		mov hWinMain, eax
		;invoke crt_malloc, bufSize
		;mov ptrBuffer, eax
		invoke _createUI 

		;------------------------------------------------
		; 功能测试代码，测试完后应当删除
		;invoke _addUserToList, addr szUsername, 2, hFriendList
		;invoke _addUserToList, addr szUsername, 1, hOnlineUserList
		;invoke _addUserToList, addr szStatic, 1, hOnlineUserList
		;------------------------------------------------

		invoke _switchChatRoom, 0, 1 ;将当前窗口切换到大厅
	.elseif eax == WM_COMMAND ; 按钮按下
		mov eax, wParam
		.if eax == LOGIN_BUTTON_HANDLE 
			;登录
			invoke _login
		.elseif eax == LOGON_BUTTON_HANDLE
			;注册
			invoke _logon
		.elseif eax == ADD_FRIEND_BUTTON_HANDLE 
			;加好友
			invoke _getUsernameByRow, curOnlineListRow, hOnlineUserList
			invoke _addUserToList, addr ptrUsername, 3, hFriendList 
			; TODO 向Server发送请求
			invoke clientAddFriend, addr ptrUsername
		.elseif eax == RETURN_TO_HALL_BUTTON_HANDLE 
			;返回大厅
			invoke _switchChatRoom, 0, 1
		.elseif eax == DELETE_FRIEND_BUTTON_HANDLE
			;删除好友
			invoke _getUsernameByRow, curFriendListRow, hFriendList
			invoke _deleteUserFromList, addr ptrUsername, hFriendList
			; TODO 向Server发送请求
			invoke clientDeleteFriend, addr ptrUsername
		.elseif eax == SEND_BUTTON_HANDLE
			invoke _SendMessage
		.elseif eax == CLEAR_BUTTON_HANDLE
			invoke _ClearEditor
		.elseif eax == BOLD_BUTTON_HANDLE
			invoke _SetCharEffect, 0
		.elseif eax == ITALICS_BUTTON_HANDLE
			invoke _SetCharEffect, 1
		.elseif eax == UNDERLINE_BUTTON_HANDLE
			invoke _SetCharEffect, 2
		.elseif eax == STRIKEOUT_BUTTON_HANDLE
			invoke _SetCharEffect, 3
		.elseif eax == TEXTFONT_BUTTON_HANDLE
			invoke _SetCharFont
		.endif
	.elseif eax == WM_NOTIFY
		mov esi, lParam
		mov edi, wParam ;发出消息的控件的句柄
		assume esi:ptr NMHDR
		.if [esi].code == NM_DBLCLK
			.if edi == 2 ;从FriendList发出
				assume esi:ptr NMITEMACTIVATE
				mov edi, [esi].iItem
				invoke _switchChatRoom, edi, 0
			.endif
		.endif
		assume esi:ptr NMHDR
		.if [esi].code == NM_CLICK
			.if edi == 1 ; 从OnlineList发出
				assume esi:ptr NMITEMACTIVATE
				mov edi, [esi].iItem
				mov curOnlineListRow, edi
			.elseif edi == 2; 从FriendList发出
				assume esi:ptr NMITEMACTIVATE
				mov edi, [esi].iItem
				mov curFriendListRow, edi
			.endif
		.endif
	.elseif eax == WM_USERJOIN ; 新的用户登录进入大厅
		invoke _addUserToList, wParam, 1, hOnlineUserList
	.elseif eax == WM_USERLEAVE
		invoke _deleteUserFromList, wParam, hOnlineUserList
	.elseif eax == WM_APPENDFRIEND
		invoke _addUserToList, wParam, lParam, hFriendList
	.elseif eax == WM_CHANGEFRISTATUS
		; TODO 切换好友状态
		invoke _changeFriendStatus, wParam, lParam
	.elseif eax == WM_APPENDROOMMSG
		; TODO 向大厅聊天室发信
	.elseif eax == WM_APPEND1TO1MSG
		; TODO 向私聊窗口发信
	.else
		invoke DefWindowProc, hWnd, uMsg, wParam, lParam
		ret
	.endif
	mov eax, 0
	ret
_ClientWindowProc ENDP



;----------------------------------------------------------
_ClientWindowMain PROC
; 主窗口程序
;----------------------------------------------------------
	local @stWndClass:WNDCLASSEX
	local @stMsg:MSG

	mov hInstance, eax

	; 初始化stWndClass
	invoke RtlZeroMemory, addr @stWndClass, sizeof @stWndClass
	mov eax, hInstance
	mov @stWndClass.hInstance, eax
	invoke LoadIcon, NULL, IDI_APPLICATION	; 加载默认应用程序图标
	mov @stWndClass.hIcon, eax
	invoke LoadCursor, NULL, IDC_ARROW	;加载鼠标
	mov @stWndClass.hCursor, eax
	mov @stWndClass.cbSize, sizeOf WNDCLASSEX
	mov @stWndClass.style, CS_HREDRAW or CS_VREDRAW
	mov @stWndClass.hbrBackground, COLOR_WINDOW
	mov @stWndClass.lpszClassName, offset szClientWindowClassName
	mov @stWndClass.lpfnWndProc, offset _ClientWindowProc
	invoke RegisterClassEx, addr @stWndClass ; 将设置好的stWndClass进行注册

	; 建立窗口
	invoke CreateWindowEx, WS_EX_CLIENTEDGE, offset szClientWindowClassName, offset szClientWindowName,\
			WS_OVERLAPPEDWINDOW, CW_USEDEFAULT, CW_USEDEFAULT,\
			1280, 720,\ ; 应该是窗口大小
			NULL, NULL, hInstance, NULL
	
	invoke ShowWindow, hWinMain, SW_SHOWNORMAL
	invoke UpdateWindow, hWinMain


	.while TRUE
		invoke GetMessage, addr @stMsg, 0, 0, 0
		.break .if eax==0
		invoke TranslateMessage, addr @stMsg
		invoke DispatchMessage, addr @stMsg
	.endw
	ret
_ClientWindowMain ENDP

main PROC
	;invoke StdOut, addr inputipHint
	;invoke crt_scanf, addr inputipFormat, addr tempip
	;invoke StdOut, addr inputportHint
	;invoke crt_scanf, addr inputportFormat, addr tempport
	;invoke setIP, addr tempip, tempport
	invoke LoadLibrary, addr szMsftedit
	invoke LoadLibrary, addr szOle32
	call _ClientWindowMain
	invoke ExitProcess, 0
	ret
main ENDP
END main