include masm32rt.inc
include msvcrt.inc
includelib msvcrt.lib

AppendFriend PROTO :DWORD, status:DWORD, ID:DWORD

WM_APPENDFRIEND = WM_USER + 1
WM_APPENDMSG = WM_USER + 2
WM_CHANGESTATUS = WM_USER + 3

;==================== DATA =======================

.data
hint byte "test",0
hint_parserfriend byte "start parse friends",0dh,0ah,0

extern hWinMain:dword


;----------------------------------------------------------
parseFriendList PROC USES edx ebx edi, _buffer:PTR BYTE
;解析传入的字符串，获取好友列表及其当前状态
;太坑了！！！！！！！！！！！！！！print和stdout和RtlZeroMemory都会修改edx的值。。。。。
;----------------------------------------------------------
	LOCAL @username[100]:DWORD
	LOCAL @status[10]:DWORD
	LOCAL @pos:DWORD

			push edx
			invoke StdOut,addr hint_parserfriend
			pop edx
	mov edx,_buffer
	mov @pos,edx
	mov bl,[edx]

	.while TRUE
		.if bl==0
			.break
		.endif
		.if bl==32
			; 如果为空格
			mov bl,0
			mov [edx],bl

            push edx
			invoke RtlZeroMemory,addr @username,sizeof @username
			invoke RtlZeroMemory,addr @status,sizeof @status
			invoke crt_strcpy,addr @username,@pos
			push edx
			invoke StdOut,addr @username
			pop edx
            pop edx

			inc edx
			mov @pos,edx
			inc edx
			mov bl,[edx]

			.if bl==0
				invoke crt_strcpy,@pos,addr @status
				push edx
				invoke StdOut,addr @status
				pop edx
                pushad
                print "appendone yes",13,10
				.if @status[0]==49
					print "appendone 49",13,10
					invoke SendMessage, hWinMain, WM_APPENDFRIEND, addr @username, 1
				.elseif @status[0]==48
					print "appendone 48",13,10
					invoke SendMessage, hWinMain, WM_APPENDFRIEND, addr @username, 0
				.endif
					print "appendone over",13,10
			    popad
				.break
			.elseif bl==32
				mov bl,0
				mov [edx],bl
				invoke crt_strcpy,@pos,addr @status
				push edx
				invoke StdOut,addr @status
				pop edx
			.endif

            pushad
            print "appendone yes",13,10
            .if @status[0]==49
                print "appendone 49",13,10
				invoke SendMessage, hWinMain, WM_APPENDFRIEND, addr @username, 1
            .elseif @status[0]==48
                print "appendone 48",13,10
				invoke SendMessage, hWinMain, WM_APPENDFRIEND, addr @username, 0
            .endif
            print "appendone over",13,10
            popad	
	
			inc edx
			mov @pos,edx
			dec edx
		.endif

		inc edx
		mov bl,[edx]
	.endw

	ret

parseFriendList ENDP



END 