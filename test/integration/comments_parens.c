#include "test.h"

#define C
/* yay */
/* yeah
 * woo
 */
// nice
#define E /* lol \
          */ (4)
//#undef E

#pragma \
  VERSION \
  "Software Product, Version 12345.A.01.05"

#define A (2 + 3)

int F = 3;
#define F (4 + F)
#define x (4 + y)
#define y (2 * x)
// only one interpretation is available for each token at a time: object-like or
// function-like; however, if the token is called as a function when it is an
// object, or an object when it is a function, the macro goes unexpanded
#define CA(x) #x

/* the below will error out */
/* #define STRINGIFY(x) #c */
/* char * aa = STRINGIFY(a); */

#define AC(x, y) x ## y
//#define CA "asdf"

char * a = AC(b, c);

#ifdef CA
int main() {
  int a = x + y + E + A;
  int b = y + x + F;
  printf("a: %d\n", a);
  printf(ASDF CA(a) CA(a) "\n");
  // printf(ASDF CA(AC(b, c)) CA(a) CA(a) "\n");
}
#else
int main() {
  printf("hello\n");
}
#endif  /* CA */
