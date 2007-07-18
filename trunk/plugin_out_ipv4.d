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
import std.socket;
import std.socketstream;
import std.string;


import console;
import pluginclasses;
import general;
import libini;
import dmxnode;
import dmxdevbus;
import dmxp;
import dmxfunction;

const char[] plugin_name = "IPv4_Out";

const char[] default_port = "1234";

class dmxconn {
	char []host;
	ushort port;
	char []level;
	char []passwd;
	TcpSocket sock;
	SocketStream stream;
	
	DMXDeviceAbstract [char[]] devices;
	DMXpClient dmxpc;
	tcpout_plugin parent;

	this(tcpout_plugin parent, char []host, ushort port) {
		this.host = host;
		this.port = port;
		this.parent = parent;
	}
	
	~this() {
		//foreach (dev;devices)
		//	delete dev;
		if (dmxpc)
			delete dmxpc;
		if (stream)
			delete stream;
		if (sock) {
			sock.shutdown(SocketShutdown.BOTH);
			sock.close();
			delete sock;
		}
	}
	
	RetMessage start() {
		char []buf;
		RetMessage result;
		
		//Thread t = new Thread(&start_loop, cast(void*)ipconn, 0);
		try {
			InternetHost ih = new InternetHost;
			ih.getHostByName(host);
			InternetAddress ia = new InternetAddress(ih.addrList[0], port);
			sock = new TcpSocket();
			sock.connect(ia);
		}
		catch(Exception e)
		{
			printd(E_MT.MT_ERROR, e.msg~"\n");
			return new RetMessage(0, e.msg);
		}
		
		stream = new SocketStream(sock);
		
		dmxpc = new DMXpClient(stream);
		
		char [][char[]] dada;
		dada = dmxpc.info();

		//foreach (key,data;dada)
		//	writef("cmd %s | %s >\n", key, data);
		
		if ((level != "") && (passwd != "")) {
			result = dmxpc.login(level,passwd);
			if (!result.ret)
				printd(E_MT.MT_ERROR, result.all()~"\n");
		}

		devices = dmxpc.list_devices();

		foreach (dev ;devices) {
			if (!(dev.name in parent.devices))
				parent.devices[dev.name] = cast(DMXDeviceAbstract) dev;
			else
				printd(E_MT.MT_ERROR,std.string.format("device '%s' is already in list", dev.name));
		}
		
		return new RetMessage(1);
	}
	
	void printd(E_MT messagetype, char[] message) { parent.printd(messagetype, message); }
}

class tcpout_plugin : Output_Plugin {
	ini_obj ini_config;
	dmxconn []dcs;
	
	this(char []name) {
		super(name);
	}
	
	~this() {
		printd(E_MT.MT_DEBUG,std.string.format("Closing plugin.\n"));
		
		foreach (dc; dcs)
			delete dc;
		
		this.config = code_ini(ini_config);
		save_config();
	}
	
	RetMessage init(DMXNode node) {
		dmxconn dc;
	
		super.init(node);
		printd(E_MT.MT_DEBUG,std.string.format("Init plugin.\n"));
		
		load_config();
		ini_config = parse_ini(config);

		foreach (char []key, char[][char[]]value; ini_config) {
			if (key.strip() != "")
			if ("host" in value) {
				if (!("port" in value))
					value["port"] = default_port;
				dc = new dmxconn(this, value["host"], cast (ushort) atoi(value["port"]));
				if ("level" in value)
					dc.level = value["level"];
				if ("passwd" in value)
					dc.passwd = value["passwd"];
				dcs ~= dc;
				printd(E_MT.MT_DEBUG,std.string.format("Connecting to %s@%s:%s...\n", dc.level, value["host"], value["port"]));
				dc.start();
			} else
				printd(E_MT.MT_ERROR,std.string.format("Ignoring '%s' - missing host variable.\n", key));
		}
		return new RetMessage(1);
	}
	
	RetMessage connectTo(DMXNode node, char[] host, ushort port) {
		dmxconn dc;
		
		dc = new dmxconn(this, host, port);
		if (dc) {
			dcs ~= dc;
			return dc.start();
		}
		return new RetMessage(0);
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
	return new tcpout_plugin(plugin_name);
}