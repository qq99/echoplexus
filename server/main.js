var express = require('express'),
	_ = require('underscore'),
	crypto = require('crypto'),
	fs = require('fs'),
	redis = require('redis'),
	jade = require('jade'),
	sio = require('socket.io'),
	app = express(),
	redisC = redis.createClient(),
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
			identified = false,
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
			},
			setIdentified: function (isHe) {
				identified = isHe;
			},
			serialize: function () {
				return {
					nick : nick,
					identified: identified
				};
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
				return value.serialize();
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
		body: 'Welcome to a new experimental chat.  Change your nickname with `/nick yournickname`.  Register with `/register yourpassword`.  Identify yourself with `/identify yourpassword`.  http://i.imgur.com/Qpkx6FJh.jpg',
		type: "SYSTEM",
		timestamp: (new Date()).toJSON(),
		log: false
	});
	sio.sockets.emit('userlist', {
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
		client.setIdentified(false);

		if (newName === "") {
			socket.emit('chat', {
				nickname: SERVER,
				body: "You may not use the empty string as a nickname.",
				type: "SYSTEM",
				timestamp: (new Date()).toJSON(),
				log: false
			});
			return;
		}

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

	socket.on('help', function () {

	});

	socket.on("identify", function (data) {
		var nick = client.getNick();
		try {
			redisC.sismember("users", nick, function (err, reply) {
				if (!reply) {
					socket.emit('chat', {
						nickname: SERVER,
						type: "SYSTEM",
						timestamp: (new Date()).toJSON(),
						body: "There's no registration on file for " + nick
					});
				} else {
					redisC.hget("salts", nick, function (err, salt) {
						if (err) throw err;
						redisC.hget("passwords", nick, function (err, expectedHash) {
							if (err) throw err;
							crypto.pbkdf2(data.password, salt, 4096, 256, function (err, derivedKey) {
								if (err) throw err;

								if (derivedKey.toString() !== expectedHash) { // FAIL
									client.setIdentified(false);
									socket.emit('chat', {
										nickname: SERVER,
										type: "SYSTEM",
										timestamp: (new Date()).toJSON(),
										body: "Wrong password for " + nick
									});
									socket.broadcast.emit('chat', {
										nickname: SERVER,
										type: "SYSTEM",
										timestamp: (new Date()).toJSON(),
										body: nick + " just failed to identify himself"
									});
									socket.broadcast.emit('userlist', {
										users: clients.userlist()
									});
									socket.emit('userlist', {
										users: clients.userlist()
									});
								} else { // ident'd
									client.setIdentified(true);
									socket.emit('chat', {
										nickname: SERVER,
										type: "SYSTEM",
										timestamp: (new Date()).toJSON(),
										body: "You are now identified for " + nick
									});
									socket.broadcast.emit('userlist', {
										users: clients.userlist()
									});
									socket.emit('userlist', {
										users: clients.userlist()
									});
								}
							});
						});
					});
				}
			});
		} catch (e) { // identification error
			socket.emit('chat', {
				nickname: SERVER,
				type: "SYSTEM",
				timestamp: (new Date()).toJSON(),
				body: "Error identifying yourself: " + e
			});
		}
	});

	socket.on('register_nick', function (data) {
		var nick = client.getNick();
		redisC.sismember("users", nick, function (err, reply) {
			if (err) throw err;
			if (!reply) { // nick is not in use
				try { // try crypto & persistence
					crypto.randomBytes(256, function (ex, buf) {
						if (ex) throw ex;
						var salt = buf.toString();
						
						crypto.pbkdf2(data.password, salt, 4096, 256, function (err, derivedKey) {
							if (err) throw err;

							redisC.sadd("users", nick, function (err, reply) {
								if (err) throw err;
							});
							redisC.hset("salts", nick, salt, function (err, reply) {
								if (err) throw err;
							});
							redisC.hset("passwords", nick, derivedKey.toString(), function (err, reply) {
								if (err) throw err;
							});

							client.setIdentified(true);
							socket.emit('chat', {
								nickname: SERVER,
								type: "SYSTEM",
								timestamp: (new Date()).toJSON(),
								body: "You have registered your nickname.  Please remember your password."
							});
							socket.broadcast.emit('userlist', {
								users: clients.userlist()
							});
							socket.emit('userlist', {
								users: clients.userlist()
							});
						});
					});
				} catch (e) {
					socket.emit('chat', {
						nickname: SERVER,
						type: "SYSTEM",
						timestamp: (new Date()).toJSON(),
						body: "Error in registering your nickname: " + e
					});
				}
			} else { // nick is already in use
				socket.emit('chat', {
					nickname: SERVER,
					type: "SYSTEM",
					timestamp: (new Date()).toJSON(),
					body: "That nickname is already registered by somebody."
				});
			}
		});
	});

	socket.on('code:change', function (data) {
		data.timestamp = (new Date()).toJSON();
		socket.broadcast.emit('code:change', data);
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
		console.log("killing ", clientID);
		clients.kill(clientID);
		sio.sockets.emit('userlist', {
			users: clients.userlist()
		});

		sio.sockets.emit('chat', {
			nickname: SERVER,
			body: client.getNick() + ' has left the chat.',
			type: "SYSTEM",
			timestamp: (new Date()).toJSON(),
			log: false
		});
	})
});
