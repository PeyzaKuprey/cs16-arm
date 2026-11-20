// dlopen smoke test: dltest <path>... — dlopens each arg, reports, exits non-zero on any failure.
#include <dlfcn.h>
#include <stdio.h>
int main(int argc, char** argv) {
	int fail = 0;
	for (int i = 1; i < argc; i++) {
		void* h = dlopen(argv[i], RTLD_NOW | RTLD_LOCAL);
		if (!h) { printf("FAIL %s: %s\n", argv[i], dlerror()); fail = 1; }
		else { printf("OK   %s\n", argv[i]); dlclose(h); }
	}
	return fail;
}
