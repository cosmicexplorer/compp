#include <stdio.h>

#define C
/* yay */
/* yeah
 * woo
 */
// nice
#define E /* lol \
          */ (4)
//#undef E

#define x (4 + y)
#define y (2 * x)

int main() {
  int a = x + y + E;
  int b = y + x;
  printf("a: %d\n", a);
}
