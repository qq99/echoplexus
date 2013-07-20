exports.ChatServer = function (sio, redisC, EventBus, Channels, ChannelModel) {

	var config = require('./config.js').Configuration,
		CHATSPACE = "/chat",
		async = require('async'),
		spawn = require('child_process').spawn,
		_= require('underscore'),
		fs = require('fs'),
		crypto = require('crypto'),
		uuid = require('node-uuid'),
		PUBLIC_FOLDER = __dirname + '/../public',
		SANDBOXED_FOLDER = PUBLIC_FOLDER + '/sandbox',
		Client = require('../client/client.js').ClientModel,
		Clients = require('../client/client.js').ClientsCollection,
		ApplicationError = require('./Error'),
		REGEXES = require('../client/regex.js').REGEXES;

	var DEBUG = config.DEBUG;

	function setIdentityToken(room, client) {
		var token,
			nick = client.get("nick");

		// check to see if a token already exists for the user
		redisC.hget("identity_token:" + room, nick, function (err, reply) {
			if (err) throw err;

			if (!reply) { // if not, make a new one
				token = uuid.v4();
				redisC.hset("identity_token:" + room, nick, token, function (err, reply) { // persist it
					if (err) throw err;
					client.identity_token = token; // store it on the client object
				});
			} else {
				token = reply;
				client.identity_token = token; // store it on the client object
			}
		});
	}
	function updatePersistedMessage(room, mID, newMessage, callback) {
		var mID = parseInt(mID, 10),
			newBody = newMessage.body,
			alteredMsg;

		// get the pure message
		redisC.hget("chatlog:" + room, mID, function (err, reply) {
			if (err) throw err;

			alteredMsg = JSON.parse(reply); // parse it

			// is it within an allowable time period?  if not set, allow it
			if (config.chat &&
				config.chat.edit &&
				config.chat.edit.maximum_time_delta) {

				var oldestPossible = Number(new Date()) - config.chat.edit.maximum_time_delta; // now - delta
				if (alteredMsg.timestamp < oldestPossible) {
					callback(new Error("Message too old to be edited"));
				} // trying to edit something too far back in time
			}


			alteredMsg.body = newBody; // alter it

			// overwrite the old message with the altered chat message
			redisC.hset("chatlog:" + room, mID, JSON.stringify(alteredMsg), function (err, reply) {
				if (err) throw err;

				callback(null, alteredMsg);
			});
		});
	}
	function urlRoot(){
		if (config.host.USE_PORT_IN_URL) {
			return config.host.SCHEME + "://" + config.host.FQDN + ":" + config.host.PORT + "/";
		} else {
			return config.host.SCHEME + "://" + config.host.FQDN + "/";
		}
	}
	function serverSentMessage (msg, room) {
		return _.extend(msg, {
			nickname: config.features.SERVER_NICK,
			type: "SYSTEM",
			timestamp: Number(new Date()),
			room: room
		});
	}
	function publishUserList (channel) {
		var room = channel.get("name"),
			authenticatedClients = channel.clients.where({authenticated: true}),
			clientsJson;

		// console.log(authenticatedClients.hasOwnProperty("toJSON"));
		
		sio.of(CHATSPACE).in(room).emit('userlist:' + room, {
			users: authenticatedClients,
			room: room
		});
	}
	function userJoined (client, room) {
		sio.of(CHATSPACE).in(room).emit('chat:' + room, serverSentMessage({
			body: client.get("nick") + ' has joined the chat.',
			client: client.toJSON(),
			class: "join",
			log: false
		}, room));
	}
	function userLeft (client, room) {
		sio.of(CHATSPACE).in(room).emit('chat:' + room, serverSentMessage({
			body: client.get("nick") + ' has left the chat.',
			id: client.get("id"),
			class: "part",
			log: false
		}, room));
	}

	function subscribeSuccess (socket, client, channel) {
		var room = channel.get("name");

		// add to server's list of authenticated clients
		// channel.clients.add(client);

		// tell the newly connected client know the ID of the latest logged message
		redisC.hget("channels:currentMessageID", room, function (err, reply) {
			if (err) throw err;
			socket.in(room).emit('chat:currentID:' + room, {
				mID: reply,
				room: room
			});
		});

		// tell the newly connected client the topic of the channel:
		redisC.hget('topic', room, function (err, reply){
			if (client.get("room") !== room) return;
			socket.in(room).emit('topic:' + room, serverSentMessage({
				body: reply,
				log: false,
			}, room));
		});

		// tell everyone about the new client in the room
		userJoined(client, room);

		// let the knewly joined know their ID
		socket.in(room).emit("client:id:" + room, {
			room: room,
			id: client.get("id")
		});

		publishUserList(channel);
	}

	var ChatServer = require('./AbstractServer.js').AbstractServer(sio, redisC, EventBus, Channels, ChannelModel);

	ChatServer.initialize({
		name: "ChatServer",
		SERVER_NAMESPACE: CHATSPACE,
		events: {
			"make_public": function (namespace, socket, channel, client, data) {
				var room = channel.get("name");

				channel.makePublic(function (err, response) {
					if (err) {
						socket.in(room).emit('chat:' + room, serverSentMessage({
							body: err.message
						}, room));
						return;
					}
					
					socket.in(room).emit('chat:' + room, serverSentMessage({
						body: "This channel is now public."
					}, room));
				});
			},
			"make_private": function (namespace, socket, channel, client, data) {
				var room = channel.get("name");

				channel.makePrivate(data.password, function (err, response) {
					if (err) {
						socket.in(room).emit('chat:' + room, serverSentMessage({
							body: err.message
						}, room));				
						return;
					}
					
					socket.in(room).emit('chat:' + room, serverSentMessage({
						body: "This channel is now private.  Please remember your password."
					}, room));
				});

			},
			"join_private": function (namespace, socket, channel, client, data) {
				var password = data.password;
				var room = channel.get("name");

				channel.authenticate(client, password, function (err, response) {
					if (err) {
						if (err instanceof ApplicationError.Authentication) {
							if (err.message === "Incorrect password.") {
								// let everyone currently in the room know that someone failed to join it
								socket.in(room).broadcast.emit('chat:' + room, serverSentMessage({
									class: "identity",
									body: client.get("nick") + " just failed to join the room."
								}, room));
							}
						}
						// let the joiner know what went wrong:
						socket.in(room).emit('chat:' + room, serverSentMessage({
							body: err.message
						}, room));
						return;
					}
				});
			},
			"nickname": function (namespace, socket, channel, client, data, ack) {
				var room = channel.get("name");

				var newName = data.nickname.replace(REGEXES.commands.nick, "").trim(),
					prevName = client.get("nick");
				client.set("identified", false);

				if (newName === "") {
					socket.in(room).emit('chat:' + room, serverSentMessage({
						body: "You may not use the empty string as a nickname.",
						log: false
					}, room));
					return;
				}

				client.set("nick", newName);
				socket.in(room).broadcast.emit('chat:' + room, serverSentMessage({
					class: "identity ack",
					body: prevName + " is now known as " + newName,
					log: false
				}, room));
				socket.in(room).emit('chat:' + room, serverSentMessage({
					class: "identity ack",
					body: "You are now known as " + newName,
					log: false
				}, room));
				publishUserList(channel);
				ack();
			},
			"topic": function (namespace, socket, channel, client, data) {
				var room = channel.get("name");

				redisC.hset('topic', room, data.topic);
				socket.in(room).emit('topic:' + room, serverSentMessage({
					body: data.topic,
					log: false
				}, room));
			},
			"chat:edit": function (namespace, socket, channel, client, data) {
				if (config.chat &&
					config.chat.edit) {

					if (!config.chat.edit.enabled) return;
					if (!config.chat.edit.allow_unidentified && !client.get("identified")) return;
				}

				var room = channel.get("name"),
					mID = parseInt(data.mID, 10),
					editResultCallback = function (err, msg) {
						if (err) {
							socket.in(room).emit('chat:' + room, serverSentMessage({
								type: "SERVER",
								body: err.message
							}, room));

							return;
						}

						socket.in(room).broadcast.emit('chat:edit:' + room, msg);
						socket.in(room).emit('chat:edit:' + room, _.extend(msg, {
							you: true
						}));
					};

				if (_.indexOf(client.mIDs, mID) !== -1) {
					updatePersistedMessage(room, mID, data, editResultCallback);
				} else { // attempt to use the client's identity token, if it exists & if it matches the one stored with the chatlog object
					redisC.hget("chatlog:identity_tokens:" + room, mID, function (err, reply) {
						if (err) throw err;

						if (client.identity_token === reply) {
							updatePersistedMessage(room, mID, data, editResultCallback);
						}
					});
				}
			},
			"chat:history_request": function (namespace, socket, channel, client, data) {
				var room = channel.get("name"),
					jsonArray = [];

				redisC.hmget("chatlog:" + room, data.requestRange, function (err, reply) {
					if (err) throw err;
					// emit the logged replies to the client requesting them
					socket.in(room).emit('chat:batch:' + room, _.without(reply, null));
				});
			},
			"chat:idle": function (namespace, socket, channel, client, data) {
				var room = channel.get("name");

				client.set("idle", true);
				client.set("idleSince", Number(new Date()));
				data.id = client.get("id");
				sio.of(CHATSPACE).in(room).emit('chat:idle:' + room, data);
				publishUserList(channel);
			},
			"chat:unidle": function (namespace, socket, channel, client, data) {
				var room = channel.get("name");

				client.set("idle", false);
				client.unset("idleSince");
				sio.of(CHATSPACE).in(room).emit('chat:unidle:' + room, {
					id: client.get("id")
				});
				publishUserList(channel);
			},
			"private_message": function (namespace, socket, channel, client, data) {
				var targetClients;
				var room = channel.get("name");

				// only send a message if it has a body & is directed at someone
				if (data.body && data.directedAt) {
					data.color = client.get("color").toRGB();
					data.nickname = client.get("nick");
					data.timestamp = Number(new Date());
					data.type = "private";
					data.class = "private";
					data.identified = client.get("identified");

					targetClients = channel.clients.where({nick: data.directedAt}); // returns an array
					if (typeof targetClients !== "undefined" &&
						targetClients.length) {

						// send the pm to each client matching the name
						_.each(targetClients, function (client) {
							client.socketRef.emit('private_message:' + room, data);
						});
						// send it to the sender s.t. he knows that it went through
						socket.in(room).emit('private_message:' + room, _.extend(data, {
							you: true
						}));
					} else {
						// some kind of error message
					}
				}
			},
			"user:set_color": function (namespace, socket, channel, client, data) {
				var room = channel.get("name");

				client.get("color").parse(data.userColorString, function (err) {
					if (err) {
						socket.in(room).emit('chat:' + room, serverSentMessage({
							type: "SERVER",
							body: err.message
						}, room));
						return;
					}

					publishUserList(channel);
				});
			},
			"chat": function (namespace, socket, channel, client, data) {
				var room = channel.get("name");

				if (config.chat &&
					config.chat.rate_limiting &&
					config.chat.rate_limiting.enabled) {
					
					if (client.tokenBucket.rateLimit()) return;
				}

				if (data.body) {
					data.color = client.get("color").toRGB();
					data.nickname = client.get("nick");
					data.timestamp = Number(new Date());
					data.identified = client.get("identified");

					// store in redis
					redisC.hget("channels:currentMessageID", room, function (err, reply) {
						if (err) throw err;

						var mID = 0;
						if (reply) {
							mID = parseInt(reply, 10);
						}
						redisC.hset("channels:currentMessageID", room, mID+1);

						data.mID = mID;

						// store the message ID transiently on the client object itself, for anonymous editing
						if (!client.mIDs) {
							client.mIDs = [];
						}
						client.mIDs.push(mID);

						// is there an edit token associated with this client?  if so, persist that so he can edit the message later
						if (client.identity_token) {
							redisC.hset("chatlog:identity_tokens:" + room, mID, client.identity_token, function (err, reply) {
								if (err) throw err;
							});
						}

						// store the chat message
						redisC.hset("chatlog:" + room, mID, JSON.stringify(data), function (err, reply) {
							if (err) throw err;
						});

						socket.in(room).broadcast.emit('chat:' + room, data);
						socket.in(room).emit('chat:' + room, _.extend(data, {
							you: true
						}));

						if (config.chat &&
							config.chat.webshot_previews &&
							config.chat.webshot_previews.enabled) {
							// strip out other things the client is doing before we attempt to render the web page
							var urls = data.body.replace(REGEXES.urls.image, "")
												.replace(REGEXES.urls.youtube,"")
												.match(REGEXES.urls.all_others);
							if (urls) {
								for (var i = 0; i < urls.length; i++) {
									
									var randomFilename = parseInt(Math.random()*9000,10).toString() + ".jpg"; // also guarantees we store no more than 9000 webshots at any time
									
									(function (url, fileName) { // run our screenshotting routine in a self-executing closure so we can keep the current filename & url
										var output = SANDBOXED_FOLDER + "/" + fileName,
											pageData = {};
										
										DEBUG && console.log("Processing ", urls[i]);
										// requires that the phantomjs-screenshot repo is a sibling repo of this one
										var screenshotter = spawn(config.chat.webshot_previews.PHANTOMJS_PATH,
											['./PhantomJS-Screenshot.js', url, output],
											{
												cwd: __dirname,
												timeout: 30*1000 // after 30s, we'll consider phantomjs to have failed to screenshot and kill it
											});

										screenshotter.stdout.on('data', function (data) {
											DEBUG && console.log('screenshotter stdout: ' + data.toString());
											pageData = JSON.parse(data.toString()); // explicitly cast it, who knows what type it is having come from a process
										});
										screenshotter.stderr.on('data', function (data) {
											DEBUG && console.log('screenshotter stderr: ' + data.toString());
										});
										screenshotter.on("exit", function (data) {
											DEBUG && console.log('screenshotter exit: ' + data.toString());

											pageData.webshot = urlRoot() + 'sandbox/' + fileName;
											pageData.original_url = url;
											pageData.from_mID = mID;

											sio.of(CHATSPACE).in(room).emit('webshot:' + room, pageData);
										});
									})(urls[i], randomFilename); // call our closure with our random filename
								}
							}
						}
					});
				}
			},
			"identify": function (namespace, socket, channel, client, data) {
				var room = channel.get("name");
				var nick = client.get("nick");
				try {
					redisC.sismember("users:" + room, nick, function (err, reply) {
						if (!reply) {
							socket.in(room).emit('chat:' + room, serverSentMessage({
								class: "identity err",
								body: "There's no registration on file for " + nick
							}, room));
						} else {
							async.parallel({
								salt: function (callback) {
									redisC.hget("salts:" + room, nick, callback);
								},
								password: function (callback) {
									redisC.hget("passwords:" + room, nick, callback);
								}
							}, function (err, stored) {
								if (err) throw err;
								crypto.pbkdf2(data.password, stored.salt, 4096, 256, function (err, derivedKey) {
									if (err) throw err;

									if (derivedKey.toString() !== stored.password) { // FAIL
										client.set("identified", false);
										socket.in(room).emit('chat:' + room, serverSentMessage({
											class: "identity err",
											body: "Wrong password for " + nick
										}, room));
										socket.in(room).broadcast.emit('chat:' + room, serverSentMessage({
											class: "identity err",
											body: nick + " just failed to identify himself"
										}, room));
										publishUserList(channel);
									} else { // ident'd
										client.set("identified", true);
										socket.in(room).emit('chat:' + room, serverSentMessage({
											class: "identity ack",
											body: "You are now identified for " + nick
										}, room));
										setIdentityToken(room, client);
										publishUserList(channel);
									}
								});
							});
						}
					});
				} catch (e) { // identification error
					socket.in(room).emit('chat:' + room, serverSentMessage({
						body: "Error identifying yourself: " + e
					}, room));
				}
			},
			"register_nick": function (namespace, socket, channel, client, data) {
				var room = channel.get("name");
				var nick = client.get("nick");
				redisC.sismember("users:" + room, nick, function (err, reply) {
					if (err) throw err;
					if (!reply) { // nick is not in use
						try { // try crypto & persistence
							crypto.randomBytes(256, function (ex, buf) {
								if (ex) throw ex;
								var salt = buf.toString();
								crypto.pbkdf2(data.password, salt, 4096, 256, function (err, derivedKey) {
									if (err) throw err;

									redisC.sadd("users:" + room, nick, function (err, reply) {
										if (err) throw err;
									});
									redisC.hset("salts:" + room, nick, salt, function (err, reply) {
										if (err) throw err;
									});
									redisC.hset("passwords:" + room, nick, derivedKey.toString(), function (err, reply) {
										if (err) throw err;
									});

									setIdentityToken(room, client);

									client.set("identified", true);
									socket.in(room).emit('chat:' + room, serverSentMessage({
										body: "You have registered your nickname.  Please remember your password."
									}, room));
									publishUserList(channel);
								});
							});
						} catch (e) {
							socket.in(room).emit('chat:' + room, serverSentMessage({
								body: "Error in registering your nickname: " + e
							}, room));
						}
					} else { // nick is already in use
						socket.in(room).emit('chat:' + room, serverSentMessage({
							body: "That nickname is already registered by somebody."
						}, room));
					}
				});
			},
			"in_call": function (namespace, socket, channel, client) {
				client.set("inCall", true);
				publishUserList(channel);
			},
			"left_call": function (namespace, socket, channel, client) {
				client.set("inCall", false);
				publishUserList(channel);
			},
			"unsubscribe": function (namespace, socket, channel, client) {
				var room = channel.get("name");
				userLeft(client, room);
				channel.clients.remove(client);
				publishUserList(channel);
			}
		},
		unauthenticatedEvents: ["join_private"]
	});

	ChatServer.start({
		error: function (err, socket, channel, client, data) {
			var room = channel.get("name");

			if (err) {
				if (err instanceof ApplicationError.Authentication) {
					if(!data.reconnect) 
					{
						socket.in(room).emit("chat:" + room, serverSentMessage({
							body: "This channel is private.  Please type /password [channel password] to join"
						}, room));
					}
					socket.in(room).emit("private:" + room);
				} else {
					socket.in(room).emit("chat:" + room, serverSentMessage({
						body: err.message
					}, room));

					DEBUG && console.log("ChatServer: ", err);
				}
				return;
			}
		},
		success: function (namespace, socket, channel, client,data) {
			DEBUG && console.log("Client joined ", channel.get("name"));
			subscribeSuccess(socket, client, channel);
		}
	});
};
