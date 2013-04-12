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

// Custom objects:

// shared with the client:
var Client = require('../client/client.js').Client,
	Clients = require('../client/client.js').Clients;

// Standard App:
app.use(express.static(__dirname + '/public'));

server.listen(PORT);
console.log('Listening on port', PORT);

var SERVER = "Server";

function CodeCache () {
	var currentState = "",
		mruClient = null,
		ops = [];

	return {
		set: function (state) {
			currentState = state;
			ops = [];
		},
		add: function (op, client) {
			mruClient = client;
			ops.push(op);
		},
		syncFromClient: function () {
			if (mruClient === null) return;

			mruClient.socket.emit('code:request');
		},
		syncToClient: function () {
			return {
				start: currentState,
				ops: ops
			};
		},
		remove: function (client) {
			if (mruClient === client) {
				mruClient = null;
			}
		}
	};
}

var clients = new Clients();
var codeCache = new CodeCache();

// regexes:
var NICK = /^\/nick/;

// SocketIO:
sio = sio.listen(server);

function serverSentMessage (msg) {
	return _.extend(msg, {
		nickname: SERVER,
		type: "SYSTEM",
		timestamp: (new Date()).toJSON()
	});
}

sio.sockets.on('connection', function (socket) {
	var clientID = clients.add({socketRef: socket}),
		client = clients.get(clientID);

	socket.emit('chat', serverSentMessage({
		body: 'Welcome to a new experimental chat.  Change your nickname with `/nick yournickname`.  Register with `/register yourpassword`.  Identify yourself with `/identify yourpassword`.  http://i.imgur.com/Qpkx6FJh.jpg',
		log: false
	}));
	
	socket.emit('code:authoritative_push', codeCache.syncToClient());

	sio.sockets.emit('userlist', {
		users: clients.userlist()
	});
	socket.broadcast.emit('chat', serverSentMessage({
		body: client.getNick() + ' has joined the chat.',
		client: client.serialize(),
		class: "join",
	}));

	socket.on('nickname', function (data) {
		var newName = data.nickname.replace(NICK, "").trim(),
			prevName = client.getNick();
		client.setIdentified(false);

		if (newName === "") {
			socket.emit('chat', serverSentMessage({
				body: "You may not use the empty string as a nickname.",
				log: false
			}));
			return;
		}

		client.setNick(newName);

		socket.broadcast.emit('chat', serverSentMessage({
			body: prevName + " is now known as " + newName,
			log: false
		}));
		socket.emit('chat', serverSentMessage({
			body: "You are now known as " + newName,
			log: false
		}));
		sio.sockets.emit('userlist', {
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
					socket.emit('chat', serverSentMessage({
						body: "There's no registration on file for " + nick
					}));
				} else {
					redisC.hget("salts", nick, function (err, salt) {
						if (err) throw err;
						redisC.hget("passwords", nick, function (err, expectedHash) {
							if (err) throw err;
							crypto.pbkdf2(data.password, salt, 4096, 256, function (err, derivedKey) {
								if (err) throw err;

								if (derivedKey.toString() !== expectedHash) { // FAIL
									client.setIdentified(false);
									socket.emit('chat', serverSentMessage({
										body: "Wrong password for " + nick
									}));
									socket.broadcast.emit('chat', serverSentMessage({
										body: nick + " just failed to identify himself"
									}));
									sio.sockets.emit('userlist', {
										users: clients.userlist()
									});
								} else { // ident'd
									client.setIdentified(true);
									socket.emit('chat', serverSentMessage({
										body: "You are now identified for " + nick
									}));
									sio.sockets.emit('userlist', {
										users: clients.userlist()
									});
								}
							});
						});
					});
				}
			});
		} catch (e) { // identification error
			socket.emit('chat', serverSentMessage({
				body: "Error identifying yourself: " + e
			}));
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
							socket.emit('chat', serverSentMessage({
								body: "You have registered your nickname.  Please remember your password."
							}));
							sio.sockets.emit('userlist', {
								users: clients.userlist()
							});
						});
					});
				} catch (e) {
					socket.emit('chat', serverSentMessage({
						body: "Error in registering your nickname: " + e
					}));
				}
			} else { // nick is already in use
				socket.emit('chat', serverSentMessage({
					body: "That nickname is already registered by somebody."
				}));
			}
		});
	});

	socket.on('code:cursorActivity', function (data) {
		socket.broadcast.emit('code:cursorActivity', {
			cursor: data.cursor,
			id: client.id
		});
	});
	socket.on('code:change', function (data) {
		data.timestamp = (new Date()).toJSON();
		codeCache.add(data, client);
		socket.broadcast.emit('code:change', data);
	});
	socket.on('code:full_transcript', function (data) {
		codeCache.set(data.code);
		socket.broadcast.emit('code:sync', data);
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

		codeCache.remove(client);

		clients.kill(clientID);
		sio.sockets.emit('userlist', {
			users: clients.userlist()
		});

		sio.sockets.emit('chat', serverSentMessage({
			body: client.getNick() + ' has left the chat.',
			clientID: clientID,
			class: "part",
			log: false
		}));
	});

	setInterval(codeCache.syncFromClient, 1000*30);

});
