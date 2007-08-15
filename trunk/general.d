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
import std.regexp;

extern (C) uint sleep(uint seconds);
extern (C) uint usleep(uint usec);

enum E_MT {MT_DEBUG, MT_ERROR};

E_MT mess_min_level;

const char [] NO_DESTINATIONFCT = "no_destfct";

void printd(E_MT level, char []message) {
	if (level >= mess_min_level)
		writef("%s", message);
}

/*char [] re_search(char[] regex, char[] sentence) {
	auto m = RegExp(regex);
	
	if (m.test(sentence))
		return m.replace("$1");
	return cast(char[]) null;
}*/

char [][] re_search(char []regex, char[]sentence) {
	char [][] buf;
	RegExp r = new RegExp(regex, "i");
	buf = r.exec(sentence);
	if ((buf) && (buf.length > 1))
		return buf;
	else
		return null;
}

char [][] re_search2(char[] regex, char[] sentence) {
	char [][] result;
	result.length = 2;
	auto m = RegExp(regex);
	
	if (m.test(sentence)) {
		result[0] = m.replace("$1");
		result[1] = m.replace("$2");
		return result;
	}
	return cast(char[][]) null;
}

/*! \brief used as the default return value of a d-function

 */
class RetMessage {
	int ret;
	char [][] msgs;
	
	this (int ret, char[] msg) {
		this.ret = ret;
		this.msgs.length = 1;
		this.msgs[0] = msg;
	}
	
	this (int ret) {
		this(ret, "");
	}
	
/*	char [] first() {
		if (msgs.length > 0)
			return msgs[0];
		else
			return "";
	}*/
	
	char [] all() {
		if (msgs.length > 0)
			return std.string.join(msgs, "\n");
		else
			return "";
	}
}
