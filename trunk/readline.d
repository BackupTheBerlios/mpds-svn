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
import std.c.string;
import std.string;

extern (C) {
	char *readline(char *prompt);
	void add_history(char *line);
	int rl_bind_key (int key, int (*fct)(int a, int b));
	int rl_insert(int a, int b);
	void rl_cleanup_after_signal ();
}


char[] rl_readline(char[] prompt) {
	char []buf;
	char *tmp;
	tmp = readline(std.string.toStringz(prompt));
	buf.length = strlen(tmp);
	if (buf.length > 0)
		strcpy(buf.ptr, tmp);
	else
		buf = "";
	return buf;
}

void rl_add_history(char []line) {
	add_history(std.string.toStringz(line));
}
