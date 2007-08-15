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
import std.string;
import std.file;
import std.regexp;

import general;
import pluginclasses;
import libini;
import dmxdevbus;
import dmxfunction;
import dmxfprogram;
import dmxp;

const int node_version = 0;

struct DMXF_Create_Struct {
	DMXFunction(*create)(char []name, DMXDeviceAbstract dev, char[][char[]] options);
}

/*! \brief main class of every node

 */
class DMXNode {
	char [] name;
	char [] description;
	int node_version;
	ini_obj config;
	E_MT mess_min_level;
	
	char [] plugin_dir;
	char [] config_dir;
	char [] devlib_dir;
	
	DMXDeviceAbstract [char[]] devices;
	ini_obj [char[]] dev_library;
	DMXF_Create_Struct [char[]] fct_library;
	Output_Plugin [char[]]oplugins;
	Input_Plugin [char[]]iplugins;
	
	DMXpServer dmxp;
	
	int close;

	this (char []name) {

		this.name = name;
		this.node_version = node_version;
		this.description = "standard DMXNode";
		close = false;
		mess_min_level = E_MT.MT_DEBUG;
		
		dmxp = new DMXpServer(this);
	}
	
	~this () {
		foreach (dev; devices) {
			if (dev) {
				delete dev;
				dev = null;
			}
		}
			
		close_plugins();

		delete dmxp;
	}
	
	void run() {
		char [][] ipluginlist;
		ipluginlist = std.string.split(config["general"]["input"],",");
		
		foreach (iplugin; ipluginlist) {
			if (iplugin in iplugins) {
				printd(E_MT.MT_DEBUG, std.string.format("Starting plugin '%s'...\n", iplugin));
				iplugins[iplugin].start();
			} else
				printd(E_MT.MT_ERROR, std.string.format("ERROR: plugin '%s' not found.\n", iplugin));
		}
		
		while (!close) {
			sleep(1);
		}
	}
	
	void check_config() {
		if (!("general" in config)) {
			char [][char[]] general;
			config["general"] = general;
		}
		if (!("input" in config["general"]))
			config["general"]["input"] = "";
	}
	
	void load_config() {
		printd(E_MT.MT_DEBUG, std.string.format("Loading %s config...\n", name));
		if (exists(config_dir ~ name) && isfile(config_dir ~ name) )
			config = read_ini(config_dir ~ name);
		else
			printd(E_MT.MT_DEBUG, "No config found.\n");
		check_config();
	}
	
	int add_to_library(char[] libfile) {
		ini_obj ini_dev;
		char [] content;
	
		if (exists(libfile) && isfile(libfile) ) {
			content = cast(char[]) read(libfile);
			ini_dev = parse_ini(content);
			this.dev_library[ini_dev["general"]["name"]] = ini_dev;
		} else
			printd(E_MT.MT_DEBUG, std.string.format("Can't load %s.\n", libfile));
		return 1;
	}
	
	int load_devlib() {
		char [][] dirlist;
		char [] file;
		
		auto m = RegExp("^\\.[^$]+");
		
		dirlist = listdir(devlib_dir);
		foreach (d; dirlist) {
			if (!m.test(d)) {
				printd(E_MT.MT_DEBUG, std.string.format("Adding %s to library.\n", devlib_dir~d));
				this.add_to_library(devlib_dir ~ d);
			}
		}
		return 1;
	}
	
	int load_fctlib() {
		DMXF_Create_Struct tmp;
		
		tmp.create = &DMXF_Switch.create;
		fct_library["switch"] = tmp;
		
		tmp.create = &DMXF_Range.create;
		fct_library["range"] = tmp;
		
		tmp.create = &DMXF_Bus.create;
		fct_library["bus"] = tmp;
		
		tmp.create = &DMXFP_Sinus.create;
		fct_library["sinus"] = tmp;
		
		tmp.create = &DMXFP_Linear.create;
		fct_library["linear"] = tmp;
		
		tmp.create = &DMXF_Virtual.create;
		fct_library["virtual"] = tmp;
		
		return 1;
	}
	
	DMXDeviceAbstract get_dev_from_lib(char[] libdevice, char[]name) {
		ini_obj ini_dev;
		DMXDeviceAbstract dev;
		DMXFunction f;
		char [][]fct;
		char []type;
	
		if (libdevice in this.dev_library) {
			ini_dev = this.dev_library[libdevice];
			dev = new DMXDeviceAbstract(name);
			dev.type = ini_dev["general"]["name"];
			if ("desc" in ini_dev["general"])
				dev.description = ini_dev["general"]["desc"];
			
			foreach (char[]key, char[][char[]]value; ini_dev) {
				fct = re_search("function\\s([^$]+)", key);
				if (fct) {
					type = ini_dev[key]["type"];
					f = null;
					if (type in this.fct_library) {
						f = this.fct_library[type].create(fct[1], dev, ini_dev[key]);
					} else
						printd(E_MT.MT_ERROR, std.string.format("Unknown function type '%s'.\n", type));
					
					if (f) {
						dev.functions[f.name] = f;
					}
				}
			}
			return dev;
		} else {
			printd(E_MT.MT_ERROR, std.string.format("No device of type '%s' found in library.\n", libdevice));
			return null;
		}
	}
	
	int load_devices() {
		char []name;
		char []destination_dev;
		char [][]buf;
		DMXDeviceAbstract dev;
		DMXDeviceAbstract destination;
	
		foreach (char[]key, char[][char[]]value; this.config) {
			buf = re_search("device\\s([^$]+)", key);
			if (buf) {
				name = buf[1];
				printd(E_MT.MT_DEBUG, std.string.format("Init device %s...\n", name));

				dev = get_dev_from_lib(this.config[key]["type"], name);
				if (dev) {
					dev.description = this.config[key]["desc"];
					
					//dev.status = "";
					
					if ("std_destination" in this.config[key]) {
						destination_dev = this.config[key]["std_destination"];

						if (destination_dev in this.devices) {
							destination = this.devices[destination_dev];
						} else {
							destination = dev;
							printd(E_MT.MT_DEBUG, std.string.format("%s: '%s' has no device '%s'.\n", dev.name, this.name, destination_dev));
						}
					}
						
					foreach (fct; dev.functions) {
						if ("destfct_"~fct.name in this.config[key]) {
							fct.destfct = this.config[key]["destfct_"~fct.name];
						} else {
							fct.destfct = NO_DESTINATIONFCT;
							printd(E_MT.MT_ERROR, std.string.format("%s ERROR: '%s' has no destination function.\n", dev.name, fct.name));
						}
						
						if ("destfct_"~fct.name~"_format" in this.config[key]) {
							fct.destfct_format = this.config[key]["destfct_"~fct.name~"_format"];
						}
						
						fct.destdev = destination;
						if ("destdev_"~fct.name in this.config[key]) {
							if (this.config[key]["destdev_"~fct.name] == "this")
									fct.destdev = dev;
							else {
								if (this.config[key]["destdev_"~fct.name] in this.devices) {
									fct.destdev = this.devices[this.config[key]["destdev_"~fct.name]];
								} else {
									
									printd(E_MT.MT_DEBUG, std.string.format("%s: %s has no device '%s'.\n", dev.name, this.name, this.config[key]["destdev_"~fct.name]));
								}
							}
						}
						if (!fct.destdev) {
							printd(E_MT.MT_ERROR, std.string.format("%s ERROR: '%s' has no destination device.\n", dev.name, fct.name));
						}
						
						if ( (fct.destfct in fct.destdev.functions) && (!fct.destdev.functions[fct.destfct].active()) ) {
							printd(E_MT.MT_ERROR, std.string.format("%s ERROR: '%s' destination function is inactive.\n", dev.name, fct.name));
						}
					}
						
					this.devices[dev.name] = dev;
				} else
					printd(E_MT.MT_ERROR, std.string.format("Error while processing %s.\n", name));
			}
		}
		return 1;
	}
	
	int load_plugin(char[] d) {
		printd(E_MT.MT_DEBUG, "Loading " ~ plugin_dir ~ d ~ "...\n");
		Plugin plug = Plugin.new_plugin_from(config_dir, plugin_dir, d);
		if (plug) {
			switch (plug.type) {
				case Plugin_Type.PT_OUTPUT:	if (!(plug.name in this.oplugins)) {
									this.oplugins[plug.name] = cast(Output_Plugin) plug;
									plug.init(this);
									foreach(dev; (cast(Output_Plugin) plug).devices) {
										if (!(dev.name in this.devices)) {
											this.devices[dev.name] = dev;
										} else
											printd(E_MT.MT_ERROR, "Device '"~dev.name~"' is already in the list.\n");
									}
								} else
									printd(E_MT.MT_ERROR, std.string.format("%s is already in the list of plugins.\n", plug.name));
								break;
				case Plugin_Type.PT_INPUT:	if (!(plug.name in this.iplugins)) {
									this.iplugins[plug.name] = cast(Input_Plugin) plug;
									plug.init(this);
								} else
									printd(E_MT.MT_ERROR, std.string.format("%s is already in the list of plugins.\n", plug.name));
								break;
				default:	break;
			}
		}
		return 1;
	}
	
	int load_plugins() {
		char [][] dirlist;
		
		dirlist = listdir(plugin_dir);
		auto m = RegExp("libplugin_");

		foreach (d; dirlist) {
			if (isfile(d)) {
				if (m.test(d) != 0) {
					load_plugin(d);
				}
			}
		}
		return 1;
	}
	
	int close_plugins() {
		foreach (plugin; this.iplugins) {
			printd(E_MT.MT_DEBUG, "Unloading " ~ plugin.name ~ "...\n");
			delete plugin;
		}
		foreach (plugin; this.oplugins) {
			printd(E_MT.MT_DEBUG, "Unloading " ~ plugin.name ~ "...\n");
			delete plugin;
		}
		return 1;
	}
	
	void printd(E_MT messagetype, char[] message) {
		if (messagetype >= mess_min_level)
			general.printd(messagetype, this.name ~ ": " ~ message);
	}
}
