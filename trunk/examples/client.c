
#include <stdio.h>
#include <stdlib.h>

#include <mpds.h>

int main() {
	char *devices, *functions, *buf;
	int result;

	mpds_init();
	if (mpds_start("127.0.0.1", 1234, "user", "benutzer", &buf)) {
		result = mpds_getDevices(&devices);
		if (result) {
			printf("Devices:\n-------------\n%s\n",devices);
		} else
			printf("Can't fetch devices: %s\n",devices);
		free(devices);
		
		result = mpds_getFunctions("pr0led", &functions);
		if (result) {
			printf("Functions:\n-------------\n%s\n",functions);
		} else
			printf("Can't fetch functions: %s\n",functions);
		free(functions);
		
		result = mpds_setFunction("pr0led", "blue", "255", &buf);
		if (!result) {
			printf("Can't set function: %s\n", buf);
		}
		free(buf);
	} else
		printf("Login failed: %s\n", buf);
	mpds_free();
	
	return 1;
}
