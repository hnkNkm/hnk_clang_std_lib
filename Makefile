# Makefile for hnk_c_std_lib and its tests

CC         = gcc
NASM       = nasm
CFLAGS     = -Wall -Wextra -O2 -no-pie
NASMFLAGS  = -f elf64
AR         = ar
ARFLAGS    = rcs

LIBNAME    = libhnk_c_std_lib.a

# アセンブリソース（src/ 以下）
SRC_ASM    = src/malloc.s
OBJ_ASM    = $(SRC_ASM:.s=.o)

# test/ 配下の全ての .c ファイルをテストソースとして取得
TEST_SRC   = $(wildcard test/*.c)
# 各 test/XXX.c を test/XXX という実行ファイル名に変換
TEST_BIN   = $(patsubst test/%.c,test/%,$(TEST_SRC))

all: $(LIBNAME) $(TEST_BIN)

# ライブラリ作成ルール
$(LIBNAME): $(OBJ_ASM)
	$(AR) $(ARFLAGS) $@ $^

$(OBJ_ASM): $(SRC_ASM)
	$(NASM) $(NASMFLAGS) $< -o $@

# テスト実行ファイルのビルドルール
test/%: test/%.c $(LIBNAME) include/hnk_c_std_lib.h
	$(CC) $(CFLAGS) -Iinclude $< $(LIBNAME) -o $@

clean:
	rm -f $(OBJ_ASM) $(LIBNAME) $(TEST_BIN)

.PHONY: all clean
