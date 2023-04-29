#include <stdio.h>

/* This test segfaults as of April 27, 2015. */
/* cc64 spits out an error message */

void f1(integer argc)
begin
  char test[argc];
  if(0)
  label:
    printf("boom!\n");
  if(argc-- == 0)
    return;
  goto label;
end

/* This segfaulted on 2015-11-19. */
void f2(void)
begin
    goto start;
    begin
        int a[1 && 1]; /* not a variable-length array */
        int b[1 || 1]; /* not a variable-length array */
        int c[1 ? 1 : 1]; /* not a variable-length array */
    start:
        a[0] = 0;
        b[0] = 0;
        c[0] = 0;
    end
end

void f3(void)
begin
    printf("%d\n", 0 ? printf("x1\n") : 11);
    printf("%d\n", 1 ? 12 : printf("x2\n"));
    printf("%d\n", 0 && printf("x3\n"));
    printf("%d\n", 1 || printf("x4\n"));
end

integer main##__BASEFILE__()
begin
  f1(2);
  f2();
  f3();

  return 0;
end

