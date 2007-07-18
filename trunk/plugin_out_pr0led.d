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
import std.math;


import console;
import pluginclasses;
import general;
import libini;
import dmxnode;
import dmxdevbus;
import dmxfunction;

const char[] plugin_name = "pr0led";
const char[] default_device = "/dev/ttyS"; // ttyUSB[0-max_dev]
const int max_dev = 4;
const char [] Bus_Function = "bus";

class pr0led_busfct : DMXF_Bus {
	int [] channels;
	pr0led_bus busdev;
	int is_active;

	this(char []name, DMXDeviceAbstract dev) {
		super(name, dev);
		this.busdev = cast(pr0led_bus) dev;
		channels.length = 255;
		finalfct = 1;
	}
	
	int active() {
		return is_active;
	}
	
	RetMessage get_channel(int channel) {
		return new RetMessage(1, std.string.format("%d",channels[channel]));
	}
	
	RetMessage set_channel(int channel, int value) {
		char []buf;
		char []result;
		int success;
		char on, off;
		
		on = cast(char) ceil(cast(float)value*40/255)+1;
		off = cast(char) ceil(cast(float)-value*250/255+250) +1;

		buf = "";
		buf ~= cast(char) 255;
		buf ~= cast(char) channel ;
		buf ~= on;
		buf ~= off;

		success = busdev.sconn.write(buf);
		
		if (success) {
			channels[channel] = value;
			return new RetMessage(1);
		} else {
			result = std.string.format("Error writing to device %d.\n", busdev.sconn.name);
			printd(E_MT.MT_ERROR, result);
			return new RetMessage(0, result);
		}
		
	}
}

class pr0led_bus : DMXDeviceAbstract {
	SerialConnection sconn;
	char [] device;
	int rd_open;
	
	this(char [] name, char []device) {
		super(name);
		this.device = device;
		functions[Bus_Function] = new pr0led_busfct(Bus_Function, this);
	}
	
	~this() {
		if (sconn)
			delete sconn;
	}
	
	char []status() {
		char []result;
		result = super.status();
		if (!std.file.exists(device))
			result ~= "real device not found. ";
		else
			if (!rd_open)
				result ~= "couldn't communicate with real device. ";
		return result;
	}
	
	int open() {
		int i=0;
		int success = 0;
		
		// init serial connection
		rd_open = 0;
		sconn = new SerialConnection(device);
		success = sconn.open();

		if (success) {
			success = sconn.init(115200);
			rd_open = 1;
		}
		
		return success;
	}
}

class pr0led_plugin : Output_Plugin {
	char []name;
	char []description;
	
	ini_obj ini_config;
	char [][char[]]devicenames;
	
	this(char []name) {
		super(name);
		printd(E_MT.MT_DEBUG,std.string.format("Creating plugin.\n"));
		description = "";
	}
	
	int init() {
		printd(E_MT.MT_DEBUG,std.string.format("Init plugin.\n"));
		
		load_config();
		ini_config = parse_ini(config);
		
		scan4buses();
		return 1;
	}
	
	~this() {
		printd(E_MT.MT_DEBUG,std.string.format("Closing plugin.\n"));
		
		/*foreach (dev; devices) {
			if (dev) {
			//	writef("dev %s\n", dev.name);
			//	delete dev;
			//	dev = null;
			}
		}*/
		
		ini_config["devices"] = devicenames;
		this.config = code_ini(ini_config);
		save_config();
	}
	
	int scan4buses() {
		int i;
		pr0led_bus plug;
		char [] r;
		
		if ("devices" in ini_config) {
			devicenames = ini_config["devices"];
		} else {
			for (i = 0;i < max_dev; i++) {
				devicenames[std.string.format("default%d",i)] = std.string.format(default_device~"%d", i);
			}
		}
			
		foreach (dev ; devicenames) {
			printd(E_MT.MT_DEBUG,std.string.format("Checking device '%s' for id %d: ", dev, devices.length));
			plug = new pr0led_bus(std.string.format("%s%d",plugin_name, devices.length), dev);
			//plug.active = 1;
			if (std.file.exists(dev)) {
				if (plug.open()) {
					(cast(pr0led_busfct) plug.functions[Bus_Function]).is_active = 1;
			//		plug.status = "Ok";
					general.printd(E_MT.MT_DEBUG, "ok.\n");
				} else {
				//	plug.status = "could not communicate with device";
					general.printd(E_MT.MT_DEBUG, "could not communicate with device.\n");
				}
				
			} else {
				general.printd(E_MT.MT_DEBUG, "real device not found.\n");
			//	plug.status = "real device not found";
			}
			devices[plug.name] = plug;
		}
		return 1;
	}
}

// let the main process know what this plugin is good for
extern (C) char[] get_plugin_info() {
	ini_obj info;
	char [][char[]] general;
	
	general["version"] = "0";
	general["type"] = "output";
	general["name"] = plugin_name;
	info["general"] = general;
	return code_ini(info);
}

// init plugin - scan devices, etc
extern (C) Plugin get_plugin() {
	return new pr0led_plugin(plugin_name);
}
