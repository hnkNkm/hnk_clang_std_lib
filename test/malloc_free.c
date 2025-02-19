#include <stdio.h>
#include "hnk_c_std_lib.h"

int main() {
    printf("Allocating memory...\n");

    void* ptr = my_malloc(64);
    printf("After my_malloc() call\n");

    if (ptr) {
        printf("Memory allocated at: %p\n", ptr);
        my_free(ptr);
        printf("Memory freed successfully.\n");
    } else {
        printf("Memory allocation failed!\n");
    }

    return 0;
}
