var express = require('express'),
	_ = require('underscore'),
	crypto = require('crypto'),
	fs = require('fs'),
	redis = require('redis'),
	sio = require('socket.io'),
	app = express(),
	redisC = redis.createClient(),
	server = require('http').createServer(app),
	spawn = require('child_process').spawn,
	PUBLIC_FOLDER = __dirname + '/public',
	SANDBOXED_FOLDER = PUBLIC_FOLDER + '/sandbox';

var config = require('./config.js').Configuration;


// Custom objects:
// shared with the client:
var Client = require('../client/client.js').Client,
	Clients = require('../client/client.js').Clients,
	REGEXES = require('../client/regex.js').REGEXES;

// Standard App:
app.use(express.static(PUBLIC_FOLDER));

server.listen(config.host.PORT);

if (config.features.phantomjs_screenshot) {
	process.setgid('sandbox');
	process.setuid('sandbox');
	console.log('Now leaving the DANGERZONE!', 'New User ID:', process.getuid(), 'New Group ID:', process.getgid());
	console.log('Probably still a somewhat dangerous zone, tho.');
}

console.log('Listening on port', config.host.PORT);

function urlRoot(){
	if (config.host.USE_PORT_IN_URL) {
		return config.host.SCHEME + "://" + config.host.FQDN + ":" + config.host.PORT + "/";
	} else {
		return config.host.SCHEME + "://" + config.host.FQDN + "/";
	}
}

function CodeCache (namespace) {
	var currentState = "",
		namespace = (typeof namespace !== "undefined") ? namespace : "",
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

			mruClient.socket.emit(namespace + ':code:request');
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
// var codeCache = new CodeCache();

var editorNamespaces = ["js", "html"];
var editors = _.map(editorNamespaces, function (n) {
	return {
		namespace: n,
		codeCache: new CodeCache(n)
	};
});

// SocketIO:
sio = sio.listen(server);
sio.enable('browser client minification');
sio.enable('browser client gzip');
sio.set('log level', 1);

function serverSentMessage (msg) {
	return _.extend(msg, {
		nickname: config.features.SERVER_NICK,
		type: "SYSTEM",
		timestamp: Number(new Date())
	});
}

_.each(editors, function (obj) {
	var codeCache = obj.codeCache;
	// do once!!
	setInterval(codeCache.syncFromClient, 1000*30);
});

sio.sockets.on('connection', function (socket) {

	// let the newly connected client know the ID of the latest logged message
	redisC.hget("channels:currentMessageID", "default", function (err, reply) {
		if (err) throw err;
		socket.emit('chat:currentID', {
			ID: reply
		});
	});

	var clientID = clients.add({socketRef: socket}),
		client = clients.get(clientID);
	redisC.get('topic', function (err, res){
		socket.emit('chat', serverSentMessage({
			body: "Topic: " + res,
			log: false
		}));
	});

	_.each(editors, function (obj) {
		socket.emit(obj.namespace + ':code:authoritative_push', obj.codeCache.syncToClient());
	});

	sio.sockets.emit('userlist', {
		users: clients.userlist()
	});
	socket.broadcast.emit('chat', serverSentMessage({
		body: client.getNick() + ' has joined the chat.',
		client: client.serialize(),
		class: "join",
	}));

	socket.on('nickname', function (data) {
		var newName = data.nickname.replace(REGEXES.commands.nick, "").trim(),
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

	socket.on('help', function (data) {

	});

	socket.on('topic', function (data) {
		redisC.set('topic', data.topic);
		socket.emit('chat', serverSentMessage({
			body: "Topic: " + data.topic,
			log: false
		}));
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

	_.each(editors, function (obj) {
		var namespace = obj.namespace;
		var codeCache = obj.codeCache;
		socket.on(namespace + ':code:cursorActivity', function (data) {
			socket.broadcast.emit(namespace + ':code:cursorActivity', {
				cursor: data.cursor,
				id: client.id
			});
		});
		socket.on(namespace + ':code:change', function (data) {
			data.timestamp = Number(new Date());
			codeCache.add(data, client);
			socket.broadcast.emit(namespace + ':code:change', data);
		});
		socket.on(namespace + ':code:full_transcript', function (data) {
			codeCache.set(data.code);
			socket.broadcast.emit(namespace + ':code:sync', data);
		});
	});

	socket.on('chat:history_request', function (data) {
		console.log("requesting " + data.requestRange);
		redisC.hmget("chatlog:default", data.requestRange, function (err, reply) {
			if (err) throw err;
			console.log(reply);
			// emit the logged replies to the client requesting them
			_.each(reply, function (chatMsg) {
				if (chatMsg === null) return;
				socket.emit('chat', JSON.parse(chatMsg));
			});
		});
	});

	socket.on('chat', function (data) {
		if (data.body) {
			data.color = client.getColor().toRGB();
			data.nickname = client.getNick();
			data.timestamp = Number(new Date());

			// store in redis
			redisC.hget("channels:currentMessageID", "default", function (err, reply) {
				if (err) throw err;

				var mID = 0;
				if (reply) {
					mID = parseInt(reply, 10);
				}
				redisC.hset("channels:currentMessageID", "default", mID+1);

				data.ID = mID;

				// store the chat message
				redisC.hset("chatlog:default", mID, JSON.stringify(data), function (err, reply) {
					if (err) throw err;
				});

				socket.broadcast.emit('chat', data);
				socket.emit('chat', data);

				if (config.features.phantomjs_screenshot) {
					// strip out other things the client is doing before we attempt to render the web page
					var urls = data.body.replace(REGEXES.urls.image, "")
										.replace(REGEXES.urls.youtube,"")
										.match(REGEXES.urls.all_others);
					if (urls) {
						for (var i = 0; i < urls.length; i++) {
							
							var randomFilename = parseInt(Math.random()*9000,10).toString() + ".jpg";
							
							(function (url, fileName) { // run our screenshotting routine in a self-executing closure so we can keep the current filename & url
								var output = SANDBOXED_FOLDER + "/" + fileName,
									pageData = {};
								
								console.log("Processing ", urls[i]);
								// requires that the phantomjs-screenshot repo is a sibling repo of this one
								var screenshotter = spawn('/opt/bin/phantomjs',
									['../../phantomjs-screenshot/main.js', url, output],
									{
										cwd: __dirname
									});

								screenshotter.stdout.on('data', function (data) {
									console.log('screenshotter stdout: ' + data);
									data = data.toString(); // explicitly cast it, who knows what type it is having come from a process

									// attempt to extract any parameters phantomjs might expose via stdout
									var tmp = data.match(REGEXES.phantomjs.parameter);
									if (tmp && tmp.length) {
										var key = tmp[0].replace(REGEXES.phantomjs.delimiter, "").trim();
										var value = data.replace(REGEXES.phantomjs.parameter, "").trim();
										pageData[key] = value;
									}
								});
								screenshotter.stderr.on('data', function (data) {
									console.log('screenshotter stderr: ' + data);
								});
								screenshotter.on("exit", function (data) {
									console.log('screenshotter exit: ' + data);
									if (pageData.title && pageData.excerpt) {
										sio.sockets.emit('chat', serverSentMessage({
											body: '<<' + pageData.title + '>>: "'+ pageData.excerpt +'" (' + url + ') ' + urlRoot() + 'sandbox/' + fileName
										}));
									} else if (pageData.title) {
										sio.sockets.emit('chat', serverSentMessage({
											body: '<<' + pageData.title + '>> (' + url + ') ' + urlRoot() + 'sandbox/' + fileName
										}));
									} else {
										sio.sockets.emit('chat', serverSentMessage({
											body: urlRoot() + 'sandbox/' + fileName
										}));
									}
								});
							})(urls[i], randomFilename); // call our closure with our random filename
						}
					}
				}
			});
		}
	});
	socket.on('disconnect', function () {
		// console.log("killing ", clientID);

		_.each(editors, function (obj) {
			obj.codeCache.remove(client);
		})

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

});
