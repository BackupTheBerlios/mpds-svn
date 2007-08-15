#ifndef mpds_h
#define mpds_h

int mpds_init();
int mpds_start(char* host, unsigned short port, char* level, char* passwd, char** result);
int mpds_getDevices(char **devices);
int mpds_getFunctions(char *device, char ** functions);
int mpds_setFunction(char *device, char *func, char* value, char** result);
int mpds_free();

#endif
