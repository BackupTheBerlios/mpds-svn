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


import std.socket;
import std.socketstream;
import std.string;
import std.thread;

import general;
import dmxp;
import dmxnode;
import pluginclasses;
import libini;

const char[] plugin_name = "IPv4_In";

class IPv4Conn {
	DMXpOverTCP parent;
	Socket conn;
	char [] session;
	
	this (DMXpOverTCP parent, Socket sock) {
		this.parent = parent;
		this.conn = sock;
	}
	
	void loop() {
		char []buf;
		
		session = parent.name~conn.remoteAddress.toString();
		parent.dmxp.registerSession(session);
		
		SocketStream stream = new SocketStream(conn);
		while (! stream.eof() & !parent.node.close) {
			buf = stream.readLine();
			if (std.string.strip(buf) != "")
				stream.writeLine(parent.dmxp.command(session, std.string.strip(buf)));
			stream.writeLine("\n\n");
		}
		
		parent.dmxp.closeSession(session);
		
		stream.close();
		delete stream;
		
		conn.shutdown(SocketShutdown.BOTH);
		conn.close();
	}
}

class DMXpOverTCP  : Input_Plugin {
	TcpSocket list_socket;
	DMXpServer dmxp;
	DMXNode node;
	ini_obj ini_config;
	char[] session;
	Thread [] threads;

	this(char []name) {
		super(name);
	}
	
	~this() {
		printd(E_MT.MT_DEBUG,std.string.format("Closing plugin.\n"));
		if (list_socket) {
			list_socket.shutdown(SocketShutdown.BOTH);
			list_socket.close();
		}
		
		this.config = code_ini(ini_config);
		save_config();
	}
	
	void check_config() {
		if (!("general" in ini_config)) {
			char [][char[]] general;
			ini_config["general"] = general;
		}
		if (!("port" in ini_config["general"]))
			ini_config["general"]["port"] = "1234";
	}
	
	RetMessage init(DMXNode node) {
		printd(E_MT.MT_DEBUG,std.string.format("Init plugin.\n"));

		this.node = node;
		dmxp = node.dmxp;
		
		load_config();
		ini_config = parse_ini(config);
		check_config();
		
		return new RetMessage(1);
	}
	
	RetMessage start() {
		ushort port;
		Thread t = new Thread(&start_accept, cast(void*)this, 0);
		
		port = cast (ushort) atoi(ini_config["general"]["port"]);
		
		try {
			list_socket = new TcpSocket();
			list_socket.bind(new InternetAddress(port));
			list_socket.listen(3);
			t.start();
			return new RetMessage(1);
		}
		catch(Exception e)
		{
			printd(E_MT.MT_ERROR, e.msg~"\n");
			return new RetMessage(0, e.msg);
		}
	}
	
	void loop() {
		Socket conn;
		IPv4Conn ipconn;
		Thread t;
		
		printd(E_MT.MT_DEBUG, std.string.format("listening for incoming connections...\n"));
		
		while (!node.close) {
			conn = list_socket.accept();
			
			if (conn) {
				printd(E_MT.MT_DEBUG, std.string.format("Receiving new connection from %s.\n", conn.remoteAddress.toString()));
				
				ipconn = new IPv4Conn(this, conn);
				
				t = new Thread(&start_loop, cast(void*)ipconn, 0);
				//threads ~= t;
				t.start();
			} else
				printd(E_MT.MT_ERROR, "socket accept failed.\n");
		}
	}
}

int start_accept(void *ptr) {
	DMXpOverTCP p = cast(DMXpOverTCP) ptr;
	p.loop();
	return 1;
}

int start_loop(void *ptr) {
	IPv4Conn p = cast(IPv4Conn) ptr;
	p.loop();
	return 1;
}

// let the main process know what this plugin is good for
extern (C) char[] get_plugin_info() {
	ini_obj info;
	char [][char[]] general;
	
	general["version"] = "0";
	general["type"] = "input";
	general["name"] = plugin_name;
	info["general"] = general;
	return code_ini(info);
}

// init plugin - scan devices, etc
extern (C) Plugin get_plugin() {
	return new DMXpOverTCP(plugin_name);
}
