; 各ブロックは16バイトのヘッダを持ち、ヘッダは以下の構造：
;   [0]: ブロックサイズ（ブロック全体のサイズ、ヘッダを含む）
;   [8]: 次の空きブロックへのポインタ（空きブロックの場合のみ利用）
; ユーザーにはヘッダの直後のアドレスが返る。

section .bss
    ; 1MB の静的ヒープ領域
    heap       resb 1048576
    ; free_list: 空きブロックの先頭ポインタ（初期状態は未初期化）
    free_list  resq 1

section .data
    ; ヒープ終端の値：heap のアドレス + 1048576
    heap_end   dq heap + 1048576

section .text
global my_malloc
global my_free

; ヘッダサイズ定義（サイズ＋次ポインタ）
%define HEADER_SIZE 16
; 分割可能な最小サイズ（ここでは、ヘッダ＋最低8バイトのユーザーデータ領域＝24バイト未満は分割しない）
%define MIN_SPLIT_SIZE (HEADER_SIZE + 8)

; ------------------------------------------------
; void* my_malloc(size_t size)
;  引数:
;      RDI = 確保するサイズ（バイト単位）
;  戻り値:
;      RAX = 確保したメモリのポインタ（失敗時はNULL）
; ------------------------------------------------
my_malloc:
    ; 0バイト要求なら NULL を返す
    test rdi, rdi
    jz .return_null

    ; アライメント調整（8バイト境界に丸める）
    mov rax, rdi
    add rax, 7
    and rax, -8
    mov rdi, rax

    ; 必要ブロックサイズ = 要求サイズ + ヘッダサイズ
    mov rax, rdi
    add rax, HEADER_SIZE
    mov rcx, rax    ; rcx に調整後の必要サイズ

    ; free_list をチェック、NULLならヒープを初期化
    mov rsi, [free_list]
    test rsi, rsi
    jnz .search_block

    ; ヒープ初期化：ヒープ全体を1つの空きブロックにする
    mov rsi, heap
    mov [free_list], rsi
    ; ブロックサイズ = heap_end - heap
    mov rax, [heap_end]
    sub rax, heap
    mov [rsi], rax
    ; 次ポインタを初期化
    mov qword [rsi+8], 0

.search_block:
    ; rsi: 現在の空きブロックの先頭アドレス
    ; rbx: 直前のブロック（更新用、無ければ0）
    xor rbx, rbx

.search_loop:
    test rsi, rsi
    jz .return_null       ; 空きブロックが見つからなければ失敗

    ; 現在のブロックサイズを取得
    mov rdx, [rsi]        ; rdx = ブロックサイズ（ヘッダ含む）
    cmp rdx, rcx          ; 必要サイズと比較
    jb .not_enough

    ; 十分なサイズがある
    ; 残りサイズ = 現在のブロックサイズ - 必要サイズ
    mov r8, rdx
    sub r8, rcx
    ; 分割可能か判定：残りサイズが MIN_SPLIT_SIZE 以上なら分割する
    mov r9, MIN_SPLIT_SIZE
    cmp r8, r9
    jb .use_whole_block

    ; --- ブロック分割 ---
    ; 割り当て部分：先頭 rcx バイトを使用
    ; 残り部分：r8 バイト、アドレスは (rsi + rcx)
    lea r10, [rsi + rcx]
    ; 新たな空きブロックのヘッダを設定
    mov [r10], r8           ; サイズを設定
    ; 現在のブロックの次ポインタを新ブロックにコピー
    mov r11, [rsi+8]
    mov [r10+8], r11

    ; free_list から現在のブロックを除去
    cmp rbx, 0
    je .update_free_list_head_split
    mov [rbx+8], r10        ; 前のブロックの next を更新
    jmp .return_alloc

.update_free_list_head_split:
    mov [free_list], r10
    jmp .return_alloc

.use_whole_block:
    ; --- ブロック全体を使用（分割しない） ---
    cmp rbx, 0
    je .update_free_list_head_whole
    ; 前のブロックの next を現在のブロックの next に更新
    mov rax, [rsi+8]
    mov [rbx+8], rax
    jmp .return_alloc

.update_free_list_head_whole:
    mov rax, [rsi+8]
    mov [free_list], rax

.return_alloc:
    ; rsi は割り当てたブロックの先頭（ヘッダ位置）
    ; ユーザーデータ領域の先頭は (rsi + HEADER_SIZE)
    lea rax, [rsi + HEADER_SIZE]
    ret

.not_enough:
    ; 次のブロックへ
    mov rbx, rsi          ; 現在のブロックを previous として記憶
    mov rsi, [rsi+8]      ; 次の空きブロックへ
    jmp .search_loop

.return_null:
    xor rax, rax
    ret

; ------------------------------------------------
; void my_free(void* ptr)
;  引数:
;      RDI = 解放するメモリのポインタ（ユーザーデータ領域の先頭）
; ------------------------------------------------
my_free:
    test rdi, rdi
    jz .free_done
    ; ブロックヘッダの先頭を得るために HEADER_SIZE (16) バイト戻る
    sub rdi, HEADER_SIZE
    ; 単純に free_list の先頭に連結する
    mov rax, [free_list]
    mov [rdi+8], rax
    mov [free_list], rdi
.free_done:
    ret

; ------------------------------------------------
; NX対応：実行可能スタックの警告を回避
section .note.GNU-stack noalloc
