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

;=================== CODE =========================
.code

;--------------------------------------------------------
Str_length PROC USES edi, pString:PTR BYTE       ;ָ���ַ���
;�õ��ַ�������
;���룺�ַ�����ַ
;�������eax
;--------------------------------------------------------
    mov edi, pString       ;�ַ�������
    mov eax, 0             ;�ַ�������
L1: cmp BYTE PTR[edi],0
    je L2                  ;�ǣ��˳�
    inc edi                ;��ָ����һ���ַ�
    inc eax                ;��������1
    jmp L1
L2: ret
Str_length ENDP



;--------------------------------------
Str_copy PROC USES eax ecx esi edi,
    source:PTR BYTE,       ; source string
    target:PTR BYTE        ; target string
;���ַ�����Դ�����Ƶ�Ŀ�Ĵ���
;Ҫ��Ŀ�괮�������㹻�ռ����ɴ�Դ�������Ĵ���
;--------------------------------------
    INVOKE Str_length, source      ;EAX = Դ������
    mov ecx, eax                   ;�ظ�������
    inc    ecx                     ;���������ֽڣ��������� 1
    mov esi, source
    mov edi, target
    cld                            ;����Ϊ����
    rep    movsb                   ;�����ַ���
    ret
Str_copy ENDP



;---------------------------------------------------
Str_merge PROC USES eax edx,firstPart:PTR BYTE,secondPart:PTR BYTE
;�ַ���ƴ��
;Ҫ��Ŀ�괮�������㹻�ռ����ɴ�Դ�������Ĵ���
;---------------------------------------------------

	invoke Str_length,firstPart
	mov edx,firstPart
	add edx,eax
	invoke Str_copy,secondPart,edx
    ret

Str_merge ENDP



;----------------------------------------------------------
parseFriendList PROC USES edx ebx edi,_buffer:PTR BYTE
;����������ַ�������ȡ�����б��䵱ǰ״̬
;̫���ˣ���������������������������print��stdout��RtlZeroMemory�����޸�edx��ֵ����������
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
			; ���Ϊ�ո�
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
				invoke Str_copy,@pos,addr @status
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
				invoke Str_copy,@pos,addr @status
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