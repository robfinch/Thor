#include <stdio.h>

extern __cdecl integer printf(char *,...);

integer main##__BASEFILE__()
{
   integer x, y, z;

   for (x = 0; x < 2; x++)
   begin
      for (y = 0; y < 3; y++)
      begin
         for (z = 0; z < 3; z++)
         begin
            printf("%d %d %d\n", x, y, z);
         end
      end
   end

   return 0;
}

/* vim: set expandtab ts=4 sw=3 sts=3 tw=80 :*/
