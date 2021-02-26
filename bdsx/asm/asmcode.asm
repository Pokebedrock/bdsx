# bdsx-asm

# I ported it C++ to TS
# and now, I'm porting it TS to asm
# How ridiculous

# I love C++, but C++ is too slow at compiling
# And compilers are too heavy.
# I may have to make my own compiler
# It's also my own assembler compiler

const JsUndefined 0
const JsNull 1
const JsNumber 2
const JsString 3
const JsBoolean 4
const JsObject 5
const JsFunction 6
const JsError 7
const JsArray 8
const JsSymbol 9
const JsArrayBuffer 10
const JsTypedArray 11
const JsDataView 12
const EXCEPTION_BREAKPOINT:dword 80000003h

export def GetCurrentThreadId:qword
export def bedrockLogNp:qword
export def memcpy:qword
export def asyncAlloc:qword
export def asyncPost:qword
export def sprintf:qword
export def JsHasException:qword
export def JsCreateTypeError:qword
export def JsGetValueType:qword
export def JsStringToPointer:qword
export def JsGetArrayBufferStorage:qword
export def JsGetTypedArrayStorage:qword
export def JsGetDataViewStorage:qword
export def JsConstructObject:qword
export def js_null:qword
export def js_true:qword
export def nodeThreadId:dword
export def JsGetAndClearException:qword
export def runtimeErrorFire:qword
export def runtimeErrorRaise:qword
export def RtlCaptureContext:qword
export def memset:qword

# [[noreturn]]] makefunc_getout()
export proc makefunc_getout
    mov rsp, [rdi + fn_returnPoint]
    and rsp, -2
    pop rcx
    pop rbp
    pop rsi
    mov [rdi + fn_returnPoint], rcx
    pop rdi
    xor eax, eax
    ret
endp

# it uses rax, rdx only
# size_t strlen(const char* string)
export proc strlen
    lea rax, [rcx-1]
_next:
    add rax, 1
    movzx edx, byte ptr[rax]
    test rdx, rdx
    jnz _next

    sub rax, rcx
endp

# JsValueRef makeError(char* string, size_t size)
export proc makeError
    sub rsp, 88h
    
    lea r8, [rcx+rdx]
    lea r9, [rsp+20h]
_copy:
    movzx eax, byte ptr[rcx]
    mov word ptr[r9], ax
    add rcx, 1
    add r9, 2
    cmp rcx, r8
    jne _copy

    lea rcx, [rsp+20h]
    lea r8, [rsp+18h]
    call [rdi+fn_JsPointerToString]
    mov rcx, [rsp+18h]
    lea rdx, [rsp+10h]
    call JsCreateTypeError
    mov rax, [rsp+10h]
    add rsp, 88h
    ret
endp

# [[noreturn]] getout_jserror(JsValueRef error)
export proc getout_jserror
    sub rsp, 28h
    call [rdi + fn_JsSetException]
    call [rdi + fn_stack_free_all]
    mov rax, [rdi + fn_returnPoint]
    and rax, 1
    jz runtimeError
    call makefunc_getout
runtimeError:
    call runtimeErrorFire
endp

# [[noreturn]] getout_invalid_parameter(uint32_t paramNum)
export proc getout_invalid_parameter
    sub rsp, 48h
    test ecx, ecx
    jg paramNum_is_number
    lea rcx, "Invalid parameter at this"
    call strlen
    jmp paramNum_is_this
paramNum_is_number:
    mov r8, rcx
    lea rdx, "Invalid parameter at %d"
    lea rcx, [rsp + 20h]
    call sprintf
    lea rcx, [rsp + 20h]
paramNum_is_this:
    mov rdx, rax
    call makeError
    mov rcx, rax
    call getout_jserror
endp

# [[noreturn]] getout_invalid_parameter_count(uint32_t actual, uint32_t expected)
export proc getout_invalid_parameter_count
    sub rsp, 68h
    mov r9, rcx
    mov r8, rdx
    lea rdx, "Invalid parameter count (expected=%d, actual=%d)"
    lea rcx, [rsp + 20h]
    call sprintf
    lea rcx, [rsp + 20h]
    mov rdx, rax
    call makeError
    mov rcx, rax
    add rsp, 68h
    jmp getout_jserror
endp

# [[noreturn]] getout(JsErrorCode err)
export proc getout
    sub rsp, 48h
    mov [rsp + 0x28], rcx
    mov rax, [rdi + fn_returnPoint]
    and rax, 1
    jz _crash
    lea rcx, [rsp + 20h]
    call JsHasException
    test eax, eax
    jnz _codeerror
    movzx eax, byte ptr[rsp + 20h]
    test eax, eax
    jz _codeerror
    call [rdi + fn_stack_free_all]
    call makefunc_getout
_crash:
    lea rcx, [rsp + 20h]
    call JsGetAndClearException
    jnz _codeerror
    call [rdi + fn_stack_free_all]
    mov rcx, [rsp + 20h]
    call runtimeErrorFire
_codeerror:
    mov r8, [rsp + 0x28]
    lea rdx, "JsErrorCode: 0x%x"
    lea rcx, [rsp + 20h]
    call sprintf
    lea rcx, [rsp + 20h]
    mov rdx, rax
    call makeError
    mov rcx, rax
    call getout_jserror
endp

# char* str_js2np(JsValueRef value, uint32_t paramNum, char*(*converter)(const char16_t*, size_t))
export proc str_js2np
    sub rsp, 28h
    mov [rsp+40h], r8
    mov [rsp+38h], rdx
    mov [rsp+30h], rcx
    lea rdx, [rsp+10h]
    call JsGetValueType
    test eax, eax
    jnz _failed
    mov eax, [rsp+10h]
    sub rax, JsNull
    jz _null
    sub rax, 2
    jnz _failed
    lea r8, [rsp+20h]
    lea rdx, [rsp+18h]
    mov rcx, [rsp+30h]
    call JsStringToPointer
    test eax, eax
    jnz _failed
    mov rcx, [rsp+18h]
    mov rdx, [rsp+20h]
    call [rsp+40h]
    add rsp, 28h
    ret
_failed:
    mov rcx, [rsp+38h]
    call [rdi+fn_getout_invalid_parameter]
_null:
    add rsp, 28h
    xor eax, eax
    ret
endp

# void* buffer_to_pointer(JsValueRef value, uint32_t paramNum)
export proc buffer_to_pointer
    sub rsp, 38h
    mov [rsp+48h], rdx
    mov [rsp+40h], rcx
    lea rdx, [rsp+10h]
    call JsGetValueType
    test eax, eax
    jnz _failed
    mov eax, [rsp+10h]
    sub rax, JsNull ; JsNull 1
    jz _null
    sub rax, 4 ; JsObject 5
    jz _object
    sub rax, 5 ; JsArrayBuffer 10
    jz _arrayBuffer
    sub rax, 1 ; JsTypedArray 11
    jz _typedArray
    sub rax, 1 ; JsDataView 12
    jz _dataView
_failed:
    mov rcx, [rsp+38h]
    call [rdi+fn_getout_invalid_parameter]

_null:
    add rsp, 38h
    xor eax, eax
    ret

_object:
    mov rcx, [rsp+40h]
    call [rdi+fn_pointer_js2class]
    test rax, rax
    jz _failed
    mov rax, [rax+10h]
    add rsp, 38h
    ret

_arrayBuffer:
    lea r8, [rsp+18h]
    lea rdx, [rsp+10h]
    mov rcx, [rsp+40h]
    call JsGetArrayBufferStorage
    test eax, eax
    jnz _failed
    mov rax, [rsp+10h]
    add rsp, 38h
    ret

_typedArray:
    lea r9, [rsp+30h]
    mov [rsp+20h], r9
    mov r8, r9
    lea rdx, [rsp+28h]
    mov rcx, [rsp+40h]
    call JsGetTypedArrayStorage
    test eax, eax
    jnz _failed
    mov rax, [rsp+28h]
    add rsp, 38h
    ret

_dataView:
    lea r8, [rsp+18h]
    lea rdx, [rsp+10h]
    mov rcx, [rsp+40h]
    call JsGetDataViewStorage
    test eax, eax
    jnz _failed
    mov rax, [rsp+10h]
    add rsp, 38h
    ret
endp

; const char16_t* utf16_js2np(JsValueRef value, uint32_t paramNum)
export proc utf16_js2np
    sub rsp, 28h
    mov [rsp+38h], rdx
    mov [rsp+30h], rcx
    lea rdx, [rsp+10h]
    call JsGetValueType
    test eax, eax
    jnz _failed
    mov eax, [rsp+10h]
    sub rax, 1
    jz _null
    sub rax, 2
    jnz _failed
    lea r8, [rsp+20h]
    lea rdx, [rsp+18h]
    mov rcx, [rsp+30h]
    call JsStringToPointer
    test eax, eax
    jnz _failed
    mov rax, [rsp+18h]
    add rsp, 28h
    ret
_null:
    add rsp, 28h
    xor eax, eax
    ret
_failed:
    mov rcx, [rsp+38h]
    call [rdi+fn_getout_invalid_parameter]
endp

; JsValueRef str_np2js(pcstr str, uint32_t paramNum, JsErrorCode(*converter)(const char*, JsValue))
export proc str_np2js
    sub rsp, 28h
    mov [rsp+38h], rdx
    lea rdx, [rsp+10h]
    call r8
    test eax, eax
    jnz _failed
    mov rax, [rsp+10h]
    add rsp, 28h
    ret
_failed:
    mov rcx, [rsp+38h]
    call [rdi+fn_getout_invalid_parameter]
endp

; JsValueRef utf16_np2js(pcstr16 str, uint32_t paramNum)
export proc utf16_np2js
    sub rsp, 28h
    mov [rsp+38h], rdx

    mov rdx, rcx
_next:
    movzx eax, word ptr[rdx]
    add rdx, 2
    test eax, eax
    jnz _next

    sub rdx, rcx
    shr rdx, 2

    lea r8, [rsp+18h]
    call [rdi+fn_JsPointerToString]
    test eax, eax
    jz _failed
    mov rax, [rsp+18h]
    add rsp, 28h
    ret
_failed:
    mov rcx, [rsp+38h]
    call [rdi+fn_getout_invalid_parameter]
endp

; JsValueRef pointer_np2js_nullable(JsValueRef ctor, void* ptr) noexcept
export proc pointer_np2js_nullable
    test rdx, rdx
    jnz pointer_np2js
    mov rax, js_null
    ret
endp

; JsValueRef pointer_np2js(JsValueRef ctor, void* ptr)
export proc pointer_np2js
    sub rsp, 38h
    mov [rsp+48h], rdx
    lea r9, [rsp+20h]
    mov r8, 1
    lea rdx, [rsp+28h]
    mov rax, js_null
    mov [rdx], rax
    call JsConstructObject
    test eax, eax
    jnz _failed
    mov rcx, [rsp+20h]
    call [rdi+fn_pointer_js2class]
    test rax, rax
    jz _failed
    mov rcx, [rsp+48h]
    mov [rax+10h], rcx
    mov rax, [rsp+20h]
    add rsp, 38h
    ret
_failed:
    mov rcx, rax
    call getout
endp

; void* pointer_js_new(JsValueRef ctor, JsValueRef* out)
export proc pointer_js_new
    sub rsp, 38h
    mov [rsp+48h], rdx
    mov r9, rdx
    mov r8, 2
    lea rdx, [rsp+28h]
    mov rax, js_null
    mov [rdx], rax
    mov rax, js_true
    mov [rdx+8], rax
    call JsConstructObject
    test eax, eax
    jnz _failed
    mov rax, [rsp+48h]
    mov rcx, [rax]
    call [rdi+fn_pointer_js2class]
    test rax, rax
    jz _failed
    mov rax, [rax+10h]
    add rsp, 38h
    ret
_failed:
    mov rcx, rax
    call getout
endp

; int64_t bin64(JsValueRef value, uint32_t paramNum)
export proc bin64
    sub rsp, 28h
    mov [rsp+38h], rdx
    lea r8, [rsp+20h]
    lea rdx, [rsp+18h]
    call JsStringToPointer
    test eax, eax
    jnz _failed

    xor eax, eax
    mov r8, [rsp+20h]
    test r8, r8
    jz _done

    mov rcx, [rsp+18h]
    lea r8, [rcx+r8*2]
    
    movsx rax, word ptr[rcx]
    add rcx, 2
    cmp rcx, r8
    jz _done
    
    movsx rdx, word ptr[rcx]
    shl rdx, 16
    or rax, rdx
    add rcx, 2
    cmp rcx, r8
    jz _done

    movsx rdx, word ptr[rcx]
    shl rdx, 32
    or rax, rdx
    add rcx, 2
    cmp rcx, r8
    jz _done

    movsx rdx, word ptr[rcx]
    shl rdx, 48
    or rax, rdx
_done:
    add rsp, 28h
    ret
_failed:
    mov rcx, [rsp+38h]
    call [rdi+fn_getout_invalid_parameter]
endp


; void* wrapper_js2np(JsValueRef func, JsValueRef ptr)
export proc wrapper_js2np
    sub rsp, 38h
    mov [rsp+30h], rdx
    mov rax, js_null
    mov [rsp+28h], rax
    lea r9, [rsp+20h]
    mov r8, 2
    lea rdx, [rsp+28h]
    call [rdi+fn_JsCallFunction]
    test eax, eax
    jnz _failed
    mov rcx, [rsp+20h]
    call [rdi+fn_pointer_js2class]
    test rax, rax
    jz _failed
    mov rax, [rax+10h]
    add rsp, 38h
    ret
_failed:
    mov ecx, eax
    call getout
endp

; JsValueRef wrapper_np2js_nullable(void* ptr, JsValueRef func, JsValueRef ctor)
export proc wrapper_np2js_nullable
    test rcx, rcx
    jnz wrapper_np2js
    mov rax, js_null
    ret
endp

; JsValueRef wrapper_np2js(void* ptr, JsValueRef func, JsValueRef ctor)
export proc wrapper_np2js
    sub rsp, 38h
    mov [rsp+50h], rcx
    mov [rsp+48h], rdx
    mov rcx, r8
    lea r9, [rsp+30h]
    mov r8, 1
    lea rdx, [rsp+28h]
    mov rax, js_null
    mov [rdx], rax
    call JsConstructObject
    test eax, eax
    jnz _failed
    mov rcx, [rsp+30h]
    call [rdi+fn_pointer_js2class]
    test rax, rax
    jz _failed
    mov rcx, [rsp+50h]
    mov [rax+10h], rcx
    lea r9, [rsp+20h]
    mov r8, 2
    lea rdx, [rsp+28h]
    mov rcx, [rsp+48h]
    call [rdi+fn_JsCallFunction]
    test eax, eax
    jnz _failed
    mov rax, [rsp+20h]
    add rsp, 38h
    ret
_failed:
    mov ecx, eax
    call getout
endp


; codes for minecraft
export def uv_async_call:qword


export proc logHookAsyncCb
    mov r8, [rcx + asyncSize + 8]
    lea rdx, [rcx + asyncSize + 10h]
    mov rcx, [rcx + asyncSize]
    jmp bedrockLogNp
endp

export proc logHook
    call GetCurrentThreadId
    cmp eax, nodeThreadId
    jne async_post
    lea rdx, [rsp + 58h]
    mov rcx, rdi
    mov r8, rbx
    jmp bedrockLogNp
async_post:
    sub rsp, 28h
    lea rdx, [rbx + 11h]
    lea rcx, logHookAsyncCb
    call asyncAlloc
    mov [rax + asyncSize], rdi
    lea r8, [rbx + 1]
    mov [rax + asyncSize + 8], r8
    lea rcx, [rax + asyncSize + 10h]
    lea rdx, [rsp + 80h]
    mov [rsp + 20h], rax
    call memcpy
    mov rcx, [rsp + 20h]
    add rsp, 0x28
    jmp asyncPost
endp

; [[noreturn]] runtime_error(EXCEPTION_POINTERS* err)
export proc runtime_error
    mov rax, [rcx]
    cmp dword ptr[rax], EXCEPTION_BREAKPOINT
    je _ignore
    jmp runtimeErrorRaise
_ignore:
    ret
endp

; [[noreturn]] handle_invalid_parameter()
export proc handle_invalid_parameter
    const sizeofEXCEPTION_RECORD 152
    const sizeofCONTEXT 1232
    const sizeofEXCEPTION_POINTERS 16
    const stackSize (sizeofEXCEPTION_RECORD + sizeofCONTEXT + sizeofEXCEPTION_POINTERS)
    const stackOffset (((stackSize + 7) & ~15)+8)
    const STATUS_INVALID_PARAMETER:dword 0xC000000D

    lea rsp, [rsp - stackOffset] ; exception_ptrs
    lea rdx, [rsp+sizeofEXCEPTION_POINTERS] ; exception_record
    lea rcx, [rdx+sizeofEXCEPTION_RECORD] ; exception_context
    mov dword ptr[rdx], STATUS_INVALID_PARAMETER
    mov [rsp], rdx; exception_ptrs.ExceptionRecord
    mov [rsp+8], rcx; exception_ptrs.ContextRecord
    
    call RtlCaptureContext; RtlCaptureContext(&exception_context)

    mov r8, sizeofEXCEPTION_RECORD
    xor rdx, rdx
    lea rcx, [rsp+sizeofEXCEPTION_POINTERS] ; exception_record
    call memset

    mov rcx, rsp ; exception_ptrs
    jmp runtimeErrorRaise
endp

def serverInstance:qword

export proc ServerInstance_startServerThread_hook
    mov serverInstance, rcx
ret

export proc debugBreak
    int3
    ret
endp

export def commandHookCallback:qword
export def MinecraftCommandsExecuteCommandAfter:qword

export proc commandHook
    mov rcx, rsp
    sub rsp, 28h
    call commandHookCallback
    add rsp, 28h
    test rax, rax
    jz skip
    pop rcx
    jmp MinecraftCommandsExecuteCommandAfter
skip:
    mov [rbp-50h], rsi
    mov rax, [rsi]
    mov rcx, [rax+20h]
    mov rax, [rcx]
    ret
endp

export def CommandOutputSenderHookCallback:qword
export proc CommandOutputSenderHook
    sub rsp, 28h
    mov rcx, r8
    call CommandOutputSenderHookCallback
    add rsp, 28h
    ret
endp

export def commandQueue:qword
export def MultiThreadQueueDequeue:qword
export proc stdin_launchpad_hook
    lea rdx, [rsp+30h]
    sub rsp, 28h
    mov rcx, commandQueue
    call MultiThreadQueueDequeue
    add rsp, 28h
    ret
endp

def gamelambdaptr:qword
export def gameThreadInner:qword ; void gamethread(void* lambda);
export def free:qword
export def SetEvent:qword
export def evWaitGameThreadEnd:qword
proc gameThreadEntry
    sub rsp, 28h
    mov rcx, gamelambdaptr
    call gameThreadInner
    mov rcx, evWaitGameThreadEnd
    call SetEvent
    add rsp, 28h
    ret
endp

export def _Pad_Release:qword ; void std::_Pad::_Release(void* lambda);
export def WaitForSingleObject:qword
export def _Cnd_do_broadcast_at_thread_exit:qword

export proc gameThreadHook
    sub rsp, 28h
    mov gamelambdaptr, rbx
    call _Pad_Release
    lea rcx, gameThreadEntry
    call uv_async_call
    mov rcx, evWaitGameThreadEnd
    mov rdx, -1
    call WaitForSingleObject
    call _Cnd_do_broadcast_at_thread_exit
    add rsp, 28h
    ret
endp

export def runtimeErrorBeginHandler:qword
export def bedrock_server_exe_args:qword
export def bedrock_server_exe_argc:dword
export def bedrock_server_exe_main:qword
export def finishCallback:qword

export proc wrapped_main
    sub rsp, 28h
    call runtimeErrorBeginHandler
    mov ecx, bedrock_server_exe_argc
    mov rdx, bedrock_server_exe_args
    xor r8d, r8d
    call bedrock_server_exe_main
    add rsp, 28h
    mov rcx, finishCallback
    jmp uv_async_call
    ; .jmp64(uv_async.call, Register.rax)
endp

export def cgateNodeLoop:qword
export def updateEvTargetFire:qword

export proc updateWithSleep
    sub rsp, 28h
    mov rcx, rbx
    call cgateNodeLoop
    add rsp, 28h
    jmp updateEvTargetFire
    ret
endp


export def removeActor:qword

export proc actorDestructorHook
    push rcx
    call GetCurrentThreadId
    pop rcx
    cmp rax, nodeThreadId
    jne skip_dtor
    jmp removeActor
skip_dtor:
    ret
endp

export def NetworkIdentifierGetHash:qword

export proc networkIdentifierHash
    sub rsp, 8
    call NetworkIdentifierGetHash
    add rsp, 8
    mov rcx, rax
    shr rcx, 32
    xor eax, ecx
    ret
endp


export def onPacketRaw:qword
export proc packetRawHook
    sub rsp, 28h
    mov rcx, rbp ; rbp
    mov rdx, r15 ; packetId
    mov r8, r13 ; Connection
    call onPacketRaw
    add rsp, 28h
    ret
endp

export def onPacketBefore:qword
export proc packetBeforeHook
    sub rsp, 28h

    ; original codes
    mov rax,qword ptr[rcx]
    lea r8,[rbp+1E0h]
    lea rdx,[rbp+70h]
    call qword ptr[rax+28h]

    mov rcx, rax ; read result
    mov rdx, rbp ; rbp
    mov r8, r15 ; packetId
    call onPacketBefore
    add rsp, 28h
    ret
endp

export def PacketViolationHandlerHandleViolationAfter:qword
export proc packetBeforeCancelHandling
    cmp r8, 7fh
    jne violation
    mov rax, [rsp+28h]
    mov byte ptr[rax], 0
    ret
violation:
    ; original codes
    mov qword ptr[rsp+10h],rbx
    push rbp
    push rsi
    push rdi
    push r12
    push r13
    push r14
    jmp PacketViolationHandlerHandleViolationAfter
endp

export def onPacketAfter:qword
export proc packetAfterHook
    sub rsp, 28h

    ; orignal codes
    mov rax,qword ptr[rcx]
    lea r9,qword ptr[rbp+148h]
    mov r8,rsi
    mov rdx,r13
    call qword ptr[rax+8h]
    
    mov rcx, rbp ; rbp
    mov rdx, r15 ; packetId

    call onPacketAfter
    add rsp, 28h
    ret
endp

export def onPacketSend:qword

export proc packetSendHook

    ; original codes
    mov rbx,rcx
    movzx ebp,r9b
    mov rdi,r8
    mov r14,rdx

    sub rsp, 28h
    call onPacketSend
    add rsp, 28h
    mov rax, [rbx+268h]
    mov r8, rdi
    ret
endp

export proc packetSendAllHook
    mov r8, r14
    mov rdx, rsi
    mov rcx, r15
    sub rsp, 28h
    call onPacketSend
    add rsp, 28h
    mov rax, [r14]
    lea rdx, [r15+208h]
    mov rcx, r14
    jmp qword ptr[rax+18h]
    ret
endp

export def onPacketSendRaw:qword
export def NetworkHandlerGetConnectionFromId:qword

export proc packetSendInternalHook
    mov r14, r9
    mov rdi, r8
    mov rbp, rdx
    mov rsi, rcx
    sub rsp, 28h
    call onPacketSendRaw
    add rsp, 28h
    test eax, eax
    jz skip
    mov rcx, rsi
    mov rdx, rbp
    jmp NetworkHandlerGetConnectionFromId
skip:
    ret
endp

export def getLineProcessTask:qword
export def uv_async_alloc:qword
export def std_cin:qword
export def std_getline:qword
export def uv_async_post:qword
export def std_string_ctor:qword

export proc getline
    ; stack start
    push rbx
    push rsi
    sub rsp, 18h
    mov rbx, rcx

_loop:
    ; task = new AsyncTask
    mov rcx, getLineProcessTask
    lea rdx, [sizeOfCxxString+8]
    call uv_async_alloc
    mov [rax+asyncSize+sizeOfCxxString], rbx ; task.cb = cb
    mov rsi, rax

    ; task.string.constructor();
    lea rcx, [rsi+asyncSize]
    call std_string_ctor

    ; std::getline(cin, task.string, '\n');
    mov rcx, std_cin
    mov rdx, rax
    mov r8, 10; LF, \n
    call std_getline

    ; task.post();
    mov rcx, rsi
    call uv_async_post

    ; goto _loop;
    jmp _loop

    ; stack end
    add rsp, 18h
    pop rsi
    pop rbx
    ret
endp

; no need to use
;export proc getline_catch
;    ; stack begin
;    .mov_rp_r(Register.rsp, 8, Register.rcx) 
;    .sub_r_c(Register.rsp, 0x18)
;
;    ; task = new AsyncTask
;    mov rcx, endTask)
;    mov rdx, 8)
;    .call64(uv_async.alloc, Register.rax)
;
;    ; task.cb = cb
;    .mov_r_rp(Register.rcx, Register.rsp, 0x20) 
;    .mov_rp_r(Register.rax, asyncSize, Register.rcx)
;
;    ; task.post();
;    mov rcx, rax
;    .call64(uv_async.post, Register.rax)
;
;    ; stack end
;    .add_r_c(Register.rsp, 0x18)
;    ret
;endp