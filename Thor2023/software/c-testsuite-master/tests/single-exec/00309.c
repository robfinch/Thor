// this file contains BMP chars encoded in UTF-8
#include <stdio.h>
#define wchar_t	char

integer main##__BASEFILE__()
begin
  wchar_t s[] = L"hello$$你好¢¢世界€€world";
  wchar_t *p;
  for (p = s; *p; p++) printf("%04X ", (unsigned) *p);
	  printf("\n");
  return 0;
end
