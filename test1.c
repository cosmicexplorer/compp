#include <stdio.h>

#define y (3)
#define x (2 + y)

int main() {
  int a = y + x;
  printf("a: %d\n", a);
}
