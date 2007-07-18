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

import std.stdio;

extern (C) {
	int open_dev(char *name, int *f);
	int close_dev(int f);
	int init_dev(int f, int baud);
	int read_dev(int f, char *buffer, int bufsize);
	int write_dev(int f, char *buffer, int bufsize);
}

class SerialConnection {
	int f;
	char [] name;
	
	this(char[] name) {
		this.name = name;
	}
	
	~this() {
	}
	
	int open() {
		return open_dev(std.string.toStringz(name), &f);
	}
	
	int close() {
		return close_dev(f);	
	}
	
	int init(int baud) {
		return init_dev(f, baud);
	}
	
	int write(char []str) {
		return write_dev(f, str.ptr, str.length);
	}
	
	char []read(int max) {
		char []buf;
		int r;
		
		buf.length = max;
		r = read_dev(f, buf.ptr, max);
		return buf[0..r];
	}
}


