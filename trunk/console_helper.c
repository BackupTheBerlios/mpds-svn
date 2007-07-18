/*  
 * Copyright (C) 2007 Mario Kicherer (http://empanyc.net)
 * 
 * This program is free software; you can redistribute it and/or
 * modify it under the terms of the GNU General Public License
 * as published by the Free Software Foundation; either version 2
 * of the License, or (at your option) any later version.
 * 
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 * 
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.
 * 
 */ 

#include <termios.h>
#include <fcntl.h>
#include <stdio.h>
#include <unistd.h>

int init_dev(int f, int baud) {
	struct termios termios_p;
	
	switch(baud)
	{
		case 300:
			termios_p.c_cflag = B300;
			break;
		case 600:
			termios_p.c_cflag = B600;
			break;
		case 1200:
			termios_p.c_cflag = B1200;
			break;
		case 2400:
			termios_p.c_cflag = B2400;
			break;
		case 4800:
			termios_p.c_cflag = B4800;
			break;
		case 9600:
			termios_p.c_cflag = B9600;
			break;
		case 19200:
			termios_p.c_cflag = B19200;
			break;
		case 38400:
			termios_p.c_cflag = B38400;
			break;
		case 57600:
			termios_p.c_cflag = B57600;
			break;
		case 115200:
			termios_p.c_cflag = B115200;
			break;
	}
	termios_p.c_cflag |= CS8;
	termios_p.c_cflag |= CREAD;
	termios_p.c_iflag = IGNPAR | IGNBRK;
	termios_p.c_oflag = 0;
	termios_p.c_lflag = 0;
	termios_p.c_cc[VTIME] = 0;
	termios_p.c_cc[VMIN] = 1;
	tcsetattr(f, TCSANOW, &termios_p);
	tcflush(f, TCOFLUSH);  
	tcflush(f, TCIFLUSH);
	
	return 1;
}

int open_dev(char *name, int *f) {
	*f = open(name, O_WRONLY | O_NOCTTY | O_NONBLOCK);
	if (*f == -1)
		printf("\nERROR: '%s' %m\n", name);
	return (*f != -1);
}

int read_dev(int f, char *buffer, int bufsize) {
	int nbytes, ges;
	char *bufptr;
	
	ges = 0;
	bufptr = buffer;	
	while ((nbytes = read(f, bufptr, buffer + bufsize - bufptr - 1)) > 0) {
		bufptr += nbytes;
		ges += nbytes;
		if (bufptr[-1] == '\n' || bufptr[-1] == '\r')
			break;
	}
	return ges;
}

int write_dev(int f, char *buffer, int bufsize) {
	write(f, buffer, bufsize);
	return 1;
}

int close_dev(int f) {
	close(f);
	return 1;
}
