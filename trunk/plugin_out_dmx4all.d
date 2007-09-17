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


import console;
import pluginclasses;
import general;
import libini;
import dmxnode;
import dmxdevbus;
import dmxfunction;


/*
 *	TODO: scan dmesg for better automatic device recognition
 *
 */

const char[] plugin_name = "dmx4all";
const char[] default_device = "/dev/ttyUSB"; // ttyUSB[0-max_dev]
const int max_dev = 3;
const char [] Bus_Function = "bus";

/* List of known devices. */
const char[] mini_usb_dmx_interface = "USB DMX-Interface V3.36";

char[] [char[]] supported_devices;

class dmx4all_busfct : DMXF_Bus {
	dmx4all_bus busdev;
	int is_active;

	this(char []name, DMXDeviceAbstract dev) {
		super(name, dev);
		this.busdev = cast(dmx4all_bus) dev;
		finalfct = 1;
	}
	
	int active() {
		return is_active;
	}
	
	RetMessage get_channel(int channel) {
		char []buf;
		char [][]result;
		char []res;
		int success;
		
		success = busdev.sconn.write(std.string.format("c%03d?\n", channel));
		if (success) {
			buf = busdev.sconn.read(5);
			foreach (char []line; std.string.split(buf,"\n")) {
				result = re_search("^([\\d]{3})G.*", line);
				if (result)
					return new RetMessage(cast(int) std.string.atoi(result[1]));
			}
		} else {
			res = std.string.format("Error reading from device %d.\n", busdev.device);
			printd(E_MT.MT_ERROR, res);
			return new RetMessage(0, res);
		}
		return new RetMessage(0, "get_channel");
	}
	
	RetMessage set_channel(int channel, int value) {
		char []buf;
		char [][]result;
		char []res;
		int success;
		
		success = busdev.sconn.write(std.string.format("c%03dl%03d\n", channel, value));
		
		if (success) {
			buf = busdev.sconn.read(2);
	
			foreach (char []line; std.string.split(buf,"\n")) {
				result = re_search("^G", line);
				if (result)
					return new RetMessage(1);
			}
		} else {
			res = std.string.format("Error writing to device %d.\n", busdev.device);
			printd(E_MT.MT_ERROR, res);
			return new RetMessage(0, res);
		}
		return new RetMessage(0, "set_channel");
	}
}

class dmx4all_bus : DMXDeviceAbstract {
	SerialConnection sconn;
	char [] device;
	int rd_open; // real device open
	
	this(char [] name, char []device) {
		super(name);
		this.device = device;
		functions[Bus_Function] = new dmx4all_busfct(Bus_Function, this);
	}
	
	~this() {
		if (sconn)
			delete sconn;
	}
	
	// check if the device connected to sconn returns id if cmd was sent.
	int check_device(char[] id, char[] cmd) {
		int success = 0;
		char []buf;
		char []result;
		
		success = sconn.write(cmd);
		if (success) {
			buf = sconn.read(cast(int)id.length+200);
			auto m = RegExp(std.string.strip(id));
			if (m.test(std.string.strip(buf)))
				return 1;
		}
		return 0;
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
		sconn = new SerialConnection(device);
		success = sconn.open();
		if (success)
			success = sconn.init(38400);
		
		if (success) {
			// check if device is known
			foreach (title, dev; supported_devices) {
				i = 0;
				while ( ((success=check_device(dev, "i")) == 0) && (i < 3)) {
					i++;
				}
				if (success) {
					general.printd(E_MT.MT_DEBUG, std.string.format("Found '%s', ",title));
					rd_open = 1;
					return 1;
				}
			}
		}
		rd_open = 0;
		return 0;
	}
}

class dmx4all_plugin : Output_Plugin {
	char []name;
	char []description;

	ini_obj ini_config;
	char [][char[]]devicenames;
	
	this(char []name) {
		super(name);
		printd(E_MT.MT_DEBUG,std.string.format("Creating plugin.\n"));
		description = "";
		fill_supported_devices();
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
				delete dev;
				dev = null;
			}
		}*/
		
		ini_config["devices"] = devicenames;
		this.config = code_ini(ini_config);
		save_config();
	}
	
	// just fill the associative array
	void fill_supported_devices() {
		supported_devices["Mini USB-DMX interface"] =  mini_usb_dmx_interface;
	}
	
	int scan4buses() {
		int i;
		dmx4all_bus plug;
		
		if ("devices" in ini_config)
			devicenames = ini_config["devices"];
		else
			for (i = 0;i < max_dev; i++) {
				devicenames[std.string.format("default%d",i)] = std.string.format(default_device~"%d", i);
			}
			
		foreach (dev ; devicenames) {
			printd(E_MT.MT_DEBUG,std.string.format("Checking device (%s) for id %d: ", dev, devices.length));
			plug = new dmx4all_bus(std.string.format("%s%d",plugin_name, devices.length), dev);
			if (std.file.exists(dev)) {
				if (plug.open()) {
					(cast(dmx4all_busfct) plug.functions[Bus_Function]).is_active = 1;
					general.printd(E_MT.MT_DEBUG, "ok.\n");
				} else {
					//plug.status = "real device not supported";
					general.printd(E_MT.MT_DEBUG, "real device not supported.\n");
				}
				
			} else {
				general.printd(E_MT.MT_DEBUG, "real device not found.\n");
				//plug.status = "real device not found";
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
	return new dmx4all_plugin(plugin_name);
}
