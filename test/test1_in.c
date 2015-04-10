#include <stdio.h>

int b = 3;
int /* hey \
     */ d = /* */ 3 /*   \
                     */;
int c = 2;

#define CONST_VAR 42

#error hello

int main() {
  int a = CONST_VAR;
  printf("hello world! my variable is %d!\n", a);
}
