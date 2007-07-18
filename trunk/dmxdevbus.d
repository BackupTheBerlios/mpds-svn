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

import general;
import pluginclasses;
import libini;
import dmxfunction;
import dmxnode;
import dmxp;

/*const char [] Bus_Function = "bus";

// represents one dmx bus (e.g. one dmx interface)
class DMXBus : DMXDeviceAbstract {
	char [] name;

	this(char[] name) {
		super(name);
	}
	
	~this() {}
	
	RetMessage set_channel(int channel, int value) {
		if ((Bus_Function in functions) && (functions[Bus_Function].type == "bus")) {
			return (cast (DMXF_Bus) functions[Bus_Function]).set_channel(channel, value);
		} else
			return new RetMessage(0, "bus has no function set_channel.");
	}
	
	void printd(E_MT messagetype, char[] message) { general.printd(messagetype, std.string.format("%s: %s",this.name, message)); }
}*/

/*class DMXDevice : DMXDeviceAbstract {
	DMXBus bus;
	
	this (char []name, DMXDeviceAbstract parent) {
		super(name);
	}
	
	this (char []name) {
		super(name);
	}
}*/

/*class DMXDeviceVirtual : DMXDeviceAbstract {
	char []status;
	DMXpClient dmxpc;

	this (char []name, DMXpClient dmxpc) {
		super(name);
		this.dmxpc = dmxpc;
	}

	
}*/

/*! \brief the default container for functions
 
 */
class DMXDeviceAbstract {
	char [] name;
	char [] description;
	char [] type;
	char [] fix_status;
	
	DMXFunction [char []] functions;
	
	this (char []name) {
		this.name = name;
	}
	
	~this () {
		foreach (fct; functions) {
			if (fct) {
				delete fct;
				fct = null;
			}
		}
	}

	char [] status() {
		char []result = "";

		foreach (fct; functions) {
			if (!fct.finalfct) {
				if (fct.destfct == NO_DESTINATIONFCT)
					result ~= std.string.format("'%s' has no destination function. ", fct.name);
			
				if (!fct.destdev) {
					result ~= std.string.format("'%s' has no destination device. ", fct.name);
				} else {
					if (fct.destfct in fct.destdev.functions) {
						if (!fct.destdev.functions[fct.destfct].active()) {
							result ~= std.string.format("'%s' destination function '%s' is not active. ", fct.name, fct.destfct);
						}
					} else
							result ~= std.string.format("'%s' has no function '%s'. ", fct.destdev.name, fct.destfct);
				}
			}
		}
		return result;
	}

	char[] get_info(int verbose) {
		char [] result;
		
		result = std.string.format("Device '%s' ", name);
		
		if (status != "")
			result ~= "with status: "~status~"\n";
		else
			result ~= "with status: Ok\n";
			
		if (verbose) {
			result ~= std.string.format(" - Desc: %s\n - Type: %s\n", description, type);

			result ~= std.string.format(" - Functions:\n");
			foreach (fct; functions) {
				result ~= "   * "~fct.get_info(verbose);
			}
		}
		return result;
	}
	
	RetMessage chvar(char []value) {
		char [][] val;
		
		val = re_search(`^\s*([^\=]+)\=(.+)$`, value);
		if (val) {
			return change_variable(val[1], val[2]);
		} else
			return new RetMessage(0,"wrong parameters, use variable=value.");
	}
	
	RetMessage change_variable(char []val1, char[] val2) {
		switch (val1) {
			case "name" : name = val2;
				break;
			case "desc" : description = val2;
				break;
			case "type" : type = val2;
				break;
			default : return new RetMessage(0, "no such variable '"~val1~"'");
		}
		return new RetMessage(1, "variable '"~val1~"' set to '"~val2~"'");
	}
}
