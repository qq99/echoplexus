var express = require('express'),
	_ = require('underscore'),
	fs = require('fs'),
	jade = require('jade'),
	sio = require('socket.io'),
	app = express(),
	server = require('http').createServer(app),
	PORT = 9000;


// Standard App:
app.use(express.static(__dirname + '/public'));
app.get("/views/chat", function (req, res) {

});

server.listen(PORT);
console.log('Listening on port', PORT);


var SERVER = "Server";

function Clients () {
	function Client () {
		var nick = "Anonymous-" + parseInt(Math.random()*9000, 10),
			lastActivity = new Date();
		
		return {
			setNick: function(newNickname) {
				nick = newNickname;
			},
			getNick: function() {
				return nick;
			},
			isIdle: function () {
				if (((lastActivity - (new Date())) / (1000*60)) < 5) {
					return false;
				} else {
					return true;
				}
			},
			active: function () {
				lastActivity = new Date();
			}
		};
	}
	
	function ID () {
		var cur = 0;
		return {
			next: function () {
				return cur += 1;
			}
		}
	}

	var id = new ID();
	var clients = {};
	return {
		add: function () {
			var ref = id.next();
			clients[ref] = new Client();
			return ref;
		},
		get: function (id) {
			return clients[id];
		},//
		userlist: function () {
			return _.map(clients, function (value, key, list) {
				return value.getNick();
			});
		},
		kill: function (id) {
			delete clients[id];
		}
	}
}


var clients = new Clients();

// regexes:
var NICK = /^\/nick/;

// SocketIO:
sio = sio.listen(server);

sio.sockets.on('connection', function (socket) {
	var clientID = clients.add(),
		client = clients.get(clientID);

	socket.emit('chat', {
		nickname: SERVER,
		body: 'Welcome to a new experimental chat.  Try sending an image/youtube URL.  Use /nick to set your name. http://i.imgur.com/Qpkx6FJh.jpg', // https://www.youtube.com/watch?v=6NMr2VrhmFI&feature=plcp',
		type: "SYSTEM",
		timestamp: (new Date()).toJSON(),
		log: false
	});
	socket.emit('userlist', {
		users: clients.userlist()
	});
	socket.broadcast.emit('chat', {
		nickname: SERVER,
		body: client.getNick() + ' has joined the chat.',
		type: "SYSTEM",
		timestamp: (new Date()).toJSON()
	});

	socket.on('nickname', function (data) {
		var newName = data.nickname.replace(NICK, "").trim(),
			prevName = client.getNick();

		client.setNick(newName);

		socket.broadcast.emit('chat', {
			nickname: SERVER,
			body: prevName + " is now known as " + newName,
			type: "SYSTEM",
			timestamp: (new Date()).toJSON(),
			log: false
		});
		socket.emit('chat', {
			nickname: SERVER,
			body: "You are now known as " + newName,
			type: "SYSTEM",
			timestamp: (new Date()).toJSON(),
			log: false
		});
		socket.broadcast.emit('userlist', {
			users: clients.userlist()
		});
		socket.emit('userlist', {
			users: clients.userlist()
		});
	});

	socket.on('chat', function (data) {
		if (data.body) {
			data.nickname = client.getNick();
			data.timestamp = (new Date()).toJSON();
			socket.broadcast.emit('chat', data);
			socket.emit('chat', data);
		}
	});
	socket.on('disconnect', function () {
		clients.kill(clientID);
		socket.broadcast.emit('userlist', {
			users: clients.userlist()
		});

		socket.broadcast.emit('chat', {
			nickname: SERVER,
			body: client.getNick() + ' has left the chat.',
			type: "SYSTEM",
			timestamp: (new Date()).toJSON(),
			log: false
		});
	})
});
