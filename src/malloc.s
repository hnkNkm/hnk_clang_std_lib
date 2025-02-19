; Syscallに依存せず、固定ヒープ領域からメモリを確保するシンプルな実装
; フリーリスト方式

section .bss
    ; 1MB の静的ヒープ領域
    heap       resb 1048576
    ; free_list: 空きブロックの先頭ポインタ（未初期化）
    free_list  resq 1

section .data
    ; ヒープ終端の値：heapのアドレス + 1048576
    heap_end   dq (heap + 1048576)

section .text
global my_malloc
global my_free

; ------------------------------------------------
; void* my_malloc(size_t size)
;  引数:
;      RDI = 確保するサイズ（バイト単位）
;  戻り値:
;      RAX = 確保したメモリのポインタ（失敗時はNULL）
; ------------------------------------------------
my_malloc:
    mov rsi, [free_list]   ; 空きリストの先頭を取得
    test rsi, rsi          ; NULLかどうかチェック
    jz  .init_heap         ; 初回ならヒープ初期化へ
    jmp .search_block

.init_heap:
    mov rsi, heap          ; ヒープ先頭を空きブロックとして設定
    mov [free_list], rsi   ; free_list更新
    ; ヒープの終端を、レジスタに読み込んでから書き込む
    mov rax, heap_end      ; rax に heap_end の値をセット
    mov [rsi], rax         ; 現在のブロックのヘッダに heap_end を記録
    add rsi, 8             ; データ領域開始
    jmp .search_block

.search_block:
    mov rdx, rsi           ; 現在のブロックの開始アドレス（データ部分ではなくヘッダ）
    add rdx, 8             ; データ領域の先頭アドレス
    cmp rdx, [heap_end]    ; ヒープ終端と比較
    jae .malloc_fail

    mov rcx, [rsi]         ; 現在のブロックの次のブロックのアドレス（ヘッダに記録されている）
    sub rcx, rsi          ; 現在のブロックのサイズ
    cmp rcx, rdi          ; 要求サイズと比較
    jb  .next_block       ; サイズ不足なら次のブロックへ

    ; 十分なサイズがある場合、このブロックを使用する
    mov rax, rsi          ; 返すアドレス = 現在のブロックのヘッダ
    add rax, 8            ; ユーザーが使えるデータ領域
    add rsi, rdi          ; free_list を更新：現在のブロックを後方へ進める
    mov [free_list], rsi
    ret

.next_block:
    mov rsi, [rsi]        ; 次の空きブロックのアドレスに更新
    jmp .search_block

.malloc_fail:
    xor rax, rax          ; 失敗時は NULL (0) を返す
    ret

; ------------------------------------------------
; void my_free(void* ptr)
;  引数:
;      RDI = 解放するメモリのポインタ
; ------------------------------------------------
my_free:
    test rdi, rdi         ; ptrがNULLなら何もしない
    jz   .free_done
    sub  rdi, 8           ; ユーザー領域からヘッダに戻す
    ; 解放したブロックを、free_listの先頭にリンクする
    mov rax, [free_list]   ; 現在のfree_list
    mov [rdi], rax         ; 解放ブロックのヘッダに、以前のfree_listをセット
    mov [free_list], rdi   ; free_list を更新
.free_done:
    ret

; ------------------------------------------------
; NX対応：実行可能スタックの警告を回避
section .note.GNU-stack noalloc