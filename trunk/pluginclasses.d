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


import std.loader;
import std.file;
import std.string;

import general;
import libini;
import dmxdevbus;
import dmxfunction;
import dmxnode;

enum Plugin_Type {PT_OUTPUT, PT_INPUT};

/*! \brief root class for input plugins

 */
class Input_Plugin : Plugin {
	this(char[] name) {
		super(name);
		this.type = Plugin_Type.PT_INPUT;
	}
	
	RetMessage start() {
		return new RetMessage(1);
	}
	
}

/*! \brief root class for output plugins

 */
class Output_Plugin : Plugin {
	DMXDeviceAbstract [char []]devices;
	
	this(char[] name) {
		super(name);
		this.type = Plugin_Type.PT_OUTPUT;
	}

	RetMessage start() {
		return new RetMessage(1);
	}
	
}

/*! \brief root class for every type of plugin

 */
class Plugin {
	char [] name;
	char [] filename;
	char [] plugin_path;
	char [] config_path;
	char [] config;
	
	DMXNode node;
	HXModule handle;
	Plugin_Type type;
	
	this(char[] name) {
		this.name = name;
	}
	
	int init() {
		return 0;
	}
	
	RetMessage init(DMXNode node) {
		this.node = node;
		return new RetMessage(init());
	}
	
	int load_config() {
		printd(E_MT.MT_DEBUG, std.string.format("Loading config file.\n"));
		if (exists(config_path ~ name) && isfile(config_path ~ name) ) {
			config = cast(char[]) read(config_path ~ name);
			return 1;
		} else
			printd(E_MT.MT_DEBUG, std.string.format("No config found.\n"));
		return 0;
	}
	
	static Plugin new_plugin_from(char [] config_path, char [] plugin_path, char []lib) {
		char [] infostr;
		ini_obj info;
		char [] (*get_plugin_info)();
		Plugin (*get_plugin)();
		Plugin plug;
		
		HXModule handle = ExeModule_Load(plugin_path ~ lib);
		
		if (handle) {
			get_plugin_info = cast(typeof(get_plugin_info)) ExeModule_GetSymbol(handle, "get_plugin_info");
			if (get_plugin_info) {
				infostr = (*get_plugin_info)();
				
				if (infostr) {
					info = parse_ini(infostr);
					general.printd(E_MT.MT_DEBUG, std.string.format("%s is a plugin of type '%s', version %s and calls itself '%s'.\n", lib, info["general"]["type"], info["general"]["version"], info["general"]["name"]));
					switch (info["general"]["version"]) {
						case "0":
						get_plugin = cast(typeof(get_plugin)) ExeModule_GetSymbol(handle, "get_plugin");
						if (get_plugin) {
							plug = (*get_plugin)();
						
							if (plug) {
								plug.plugin_path = plugin_path;
								plug.config_path = config_path;
								plug.filename = lib;
								plug.handle = handle;

								return plug;
							} else
								general.printd(E_MT.MT_ERROR, std.string.format("No plugin object received from: %s\n", lib));
						} else
							general.printd(E_MT.MT_ERROR, std.string.format("%s is version %s but has no get_plugin().\n", lib, info["general"]["version"]));
						break;
						default: break;
					}
				} else
					general.printd(E_MT.MT_ERROR, std.string.format("No info received from: %s\n", lib));
			} else
				general.printd(E_MT.MT_ERROR, std.string.format("%s has no get_plugin_info().\n", lib));
		} else
			general.printd(E_MT.MT_ERROR, std.string.format("Can't load %s: %s\n", lib, ExeModule_Error()));
		return null;
	}
	
	int save_config() {
		write(config_path ~ name, this.config ~ "\n");
		return 1;
	}
	
	void printd(E_MT messagetype, char[] message) { general.printd(messagetype, "Plugin "~this.name ~ ": " ~ message); }
}
