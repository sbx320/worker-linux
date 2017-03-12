// If you change this, remember to also change glibc_version.redef
#pragma once
__asm__(".symver memcpy,memcpy@GLIBC_2.2.5");
__asm__(".symver memcmp,memcmp@GLIBC_2.2.5");
