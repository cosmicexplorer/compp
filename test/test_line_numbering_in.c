#include <stdio.h>

#define ASDF 3

#define AAAA() (ASDF)

int b = 3;
int /* hey \
     */ d = /* */ 3 //                          \
  /*                 */
;
int c = 2;

  #define \
  CONST_VAR \
  42

__LINE__
__FILE__
__LINE__

/* #error hello */

#define TEST_FUN(x) ((x) + CONST_VAR)

#define TEST_FUN_2(x, y, z) ((x) + (y) + (z))

int main() {
  int a = CONST_VAR;
  int b = ASDF * AAAA();          /* ASDF should expand to blank */
  int c = TEST_FUN(3); int d = TEST_FUN_2(a, b, c);
  printf("hello world! my variable is %d!\n", a);
}
