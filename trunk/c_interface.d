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

import dmxnode;
import plugin_out_ipv4;


DMXNode node;

int init(char[] host, ushort port) {
	
	node = new DMXNode("main");
	
	node.plugin_dir = "./";
	//node.config_dir = "./config/";
	//node.devlib_dir = "./devlib/";
	
	//node.load_config();
	node.load_plugins();
	//node.load_devlib();
	node.load_fctlib();
	//node.load_devices();
	
	if ("IPv4_Out" in node.oplugins) {
		(cast(tcpout_plugin) node.oplugins["IPv4_Out"]).connectTo(node, host, port);
	
		return 1;
	}
	
	return 0;
}

int start() {
	node.run();
	return 1;
}


int free() {
	delete node;
	return 1;
}