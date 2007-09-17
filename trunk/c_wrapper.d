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
import general;

import std.stdio;
import std.file;
import std.gc;
import std.moduleinit;
import std.c.string;
import std.c.stdlib;

DMXNode node;
dmxconn conn;

extern (C) void _STI_monitor_staticctor( );
extern (C) void _STD_monitor_staticdtor( );
extern (C) void _STI_critical_init( );
extern (C) void _STD_critical_term( );

extern (C) {

int mpds_init() {
	_STI_monitor_staticctor();
	_STI_critical_init();
	
	gc_init();
	_moduleCtor();
	_moduleUnitTests();

	node = new DMXNode("main");
	general.mess_min_level = E_MT.MT_ERROR;
	node.mess_min_level = E_MT.MT_ERROR;

	node.plugin_dir = "./";
	//node.config_dir = "./config/";
	//node.devlib_dir = "./devlib/";
	
	//node.load_config();
	//node.load_plugins();
	node.load_plugin("libplugin_out_ipv4.so");
	//node.load_devlib();
	node.load_fctlib();
	//node.load_devices();
	
	return 1;
}

int mpds_start(char* host, ushort port, char *level, char *passwd, char** result) {
	char [] buf;
	char[] lvl;
	char[] pwd;
	RetMessage res;
	
	buf = std.string.toString(host);
	lvl = std.string.toString(level);
	pwd = std.string.toString(passwd);
	if ("IPv4_Out" in node.oplugins) {
		res = (cast(tcpout_plugin) node.oplugins["IPv4_Out"]).connectTo(node, buf, port);
		if (res.ret) {
			conn = (cast(tcpout_plugin) node.oplugins["IPv4_Out"]).dcs[std.string.format("%s:%d",buf,port)];
			res = conn.login(lvl,pwd);
		}
		
		*result = cast(char*)  std.c.stdlib.malloc(res.all().length);
		strncpy(*result,std.string.toStringz(res.all()),res.all().length+1);
		return res.ret;
	}

	return 0;
}

int mpds_getDevices(char** devices) {
	char[] result = "";
	RetMessage res;
	
	res = conn.load_devices();
	
	if (res.ret) {
		foreach (dev;conn.parent.devices) {
			result ~= dev.name~"\n";
		}
		
		
		*devices = cast(char*) std.c.stdlib.malloc(result.length);
		strncpy(*devices,std.string.toStringz(result),result.length+1);
		
		return res.ret;
	} else {
		*devices = cast(char*) std.c.stdlib.malloc(res.all().length);
		strncpy(*devices,std.string.toStringz(res.all()),res.all().length+1);
		return res.ret;
	}
}

int mpds_getFunctions(char *device, char **functions) {
	char[] result = "";
	char[] buf;
	RetMessage res;
	
	buf = std.string.toString(device);
	if (buf in conn.parent.devices) {
		foreach(fct;conn.parent.devices[buf].functions) {
			result ~= fct.name~"\n";
		}
		
		
		*functions = cast(char*) std.c.stdlib.malloc(result.length);
		strncpy(*functions,std.string.toStringz(result),result.length+1);
		
		return 1;
	} else {
		result = "device not found";
		*functions = cast(char*) std.c.stdlib.malloc(result.length);
		strncpy(*functions,std.string.toStringz(result),result.length+1);
		return 0;
	}
}

int mpds_setFunction(char *device, char *func, char* value, char** result) {
	char[] dev;
	char[] fct;
	char[] buf;
	RetMessage res;
	
	buf = std.string.toString(value);
	
	dev = std.string.toString(device);
	if (dev in conn.parent.devices) {
		fct = std.string.toString(func);
		if (fct in conn.parent.devices[dev].functions) {
			res = conn.parent.devices[dev].functions[fct].set(buf);
			
			*result = cast(char*) std.c.stdlib.malloc(res.all().length);
			strncpy(*result,std.string.toStringz(res.all()),res.all().length+1);
			
			return res.ret;
		} else {
			buf = "function not found";
			*result = cast(char*) std.c.stdlib.malloc(buf.length);
			strncpy(*result,std.string.toStringz(buf),buf.length+1);
			return 0;
		}
	} else {
		buf = "device not found";
		*result = cast(char*) std.c.stdlib.malloc(buf.length);
		strncpy(*result,std.string.toStringz(buf),buf.length+1);
		return 0;
	}
}

int mpds_free() {
	node.close = true;

	delete node;

	_moduleDtor();
	gc_term();
	_STD_critical_term();
	_STD_monitor_staticdtor();
	return 1;
}
}
