#ifndef HNK_C_STD_LIB_H
#define HNK_C_STD_LIB_H

#include <stddef.h>

#ifdef __cplusplus
extern "C" {
#endif

void* my_malloc(size_t size);
void  my_free(void* ptr);

#ifdef __cplusplus
}
#endif

#endif // HNK_C_STD_LIB_H
