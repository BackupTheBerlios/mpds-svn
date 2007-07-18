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
import std.file;
import std.string;

import pluginclasses;
import general;
import libini;
import dmxnode;
import dmxdevbus;
import dmxfunction;
import dmxp;

extern (C) int signal(int signum, void (*terminate)(int));

const int SIGINT = 2;

DMXNode node;

extern (C) void terminate(int sig) {
	printd(E_MT.MT_DEBUG, std.string.format("Receiving signal %d.\n", sig));
	switch (sig) {
		case(2):	if (node)
					node.close = true;
			break;
		default: break;
	}
}

void main() {
	node = new DMXNode("main");
	
	node.plugin_dir = "./";
	node.config_dir = "./config/";
	node.devlib_dir = "./devlib/";
	
	node.load_config();
	node.load_plugins();
	node.load_devlib();
	node.load_fctlib();
	node.load_devices();
	
	signal(SIGINT, &terminate);

	node.run();

	delete node;
}
