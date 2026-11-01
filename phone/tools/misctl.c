/* misctl status | mis <0|1> | disc <0|1>: Personal Hotspot (MIS) state through MobileWiFi.
 * disc 1 starts or re-arms the hotspot's discovery session; wifid restarts its 90 s idle timer on it.
 * Sign with misctl.xml (com.apple.wifi.manager-access). */
#include <dlfcn.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

int main(int argc, char **argv) {
	void *h = dlopen("/System/Library/PrivateFrameworks/MobileWiFi.framework/MobileWiFi", RTLD_NOW);
	void *(*create)(void *, int) = dlsym(h, "WiFiManagerClientCreate");
	int (*getmis)(void *) = dlsym(h, "WiFiManagerClientGetMISState");
	void (*setmis)(void *, int) = dlsym(h, "WiFiManagerClientSetMISState");
	int (*getdisc)(void *) = dlsym(h, "WiFiManagerClientGetMISDiscoveryState");
	void (*setdisc)(void *, int) = dlsym(h, "WiFiManagerClientSetMISDiscoveryState");
	if (!create || !getmis || !setmis || !getdisc || !setdisc) { fprintf(stderr, "MobileWiFi symbols missing\n"); return 2; }
	void *m = create(NULL, 0);
	if (!m) { fprintf(stderr, "WiFiManagerClientCreate failed\n"); return 2; }
	if (argc == 3 && !strcmp(argv[1], "mis")) setmis(m, atoi(argv[2]));
	else if (argc == 3 && !strcmp(argv[1], "disc")) setdisc(m, atoi(argv[2]));
	else if (argc != 2 || strcmp(argv[1], "status")) { fprintf(stderr, "usage: misctl status | mis <0|1> | disc <0|1>\n"); return 1; }
	printf("mis=%d disc=%d\n", getmis(m), getdisc(m));
	return 0;
}
