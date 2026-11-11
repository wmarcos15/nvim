/* Sample for scripts/check.lua. The bugs are deliberate: they are what the
   on-save linters (cppcheck, clang-tidy analyzer) are expected to report. */
#include <stdlib.h>

int deliberate_bugs(int c) {
    int *p = 0;
    if (c) p = &c;
    *p = 1;                                  /* null dereference when c == 0 */
    int arr[4];
    for (int i = 0; i <= 4; i++) arr[i] = i; /* out of bounds */
    return arr[0];
}
