#include <stdio.h>

#define ASDF 3

#define AAAA() (ASDF)

int b = 3;
int /* hey \
     */ d = /* */ 3 //                          \
  /*                 */;
int c = 2;

#define \
  CONST_VAR \
  42

/* #error hello */

int main() {
  int a = CONST_VAR;
  int b = ASDF AAAA();          /* ASDF should expand to blank */
  printf("hello world! my variable is %d!\n", a);
}
