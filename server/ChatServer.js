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

	var DEBUG = config.DEBUG,
		initialized = false;

	function updatePersistedMessage(room, mID, newMessage, callback) {
		var mID = parseInt(mID, 10),
			newBody = newMessage.body,
			newEncryptedText,
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
			if (typeof newMessage.encrypted !== "undefined") {
				alteredMsg.encrypted = newMessage.encrypted;
			}

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


		sio.of(CHATSPACE).in(room).emit('userlist:' + room, {
			users: authenticatedClients,
			room: room
		});
	}

	function clientChanged (socket, channel, changedClient) {
		var room = channel.get("name");

		sio.of(CHATSPACE).in(room).emit('client:changed:' + room, changedClient.toJSON());
	}

	function clientRemoved (socket, channel, changedClient) {
		var room = channel.get("name");

		sio.of(CHATSPACE).in(room).emit('client:removed:' + room, changedClient.toJSON());
	}

	function emitGenericPermissionsError (socket, client) {
		var room = client.get("room");

		socket.in(room).emit('chat:' + room, serverSentMessage({
			body: "I can't let you do that, " + client.get("nick"),
			log: false
		}));
	}

	function broadcast (socket, channel, message) {
		var room = channel.get("name");

		sio.of(CHATSPACE).in(room).emit('chat:' + room, serverSentMessage({
			body: message
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
		socket.in(room).emit('topic:' + room, serverSentMessage({
			body: channel.get("topicObj"),
			log: false,
		}, room));

		// let the knewly joined know their ID
		socket.in(room).emit("client:id:" + room, {
			room: room,
			id: client.get("id")
		});

		client.antiforgery_token = uuid.v4();
		socket.in(room).emit("antiforgery_token:" + room, {
			antiforgery_token: client.antiforgery_token
		});

		publishUserList(channel);
	}

	function storePersistent (msg, room, callback) {
		// store in redis
		redisC.hget("channels:currentMessageID", room, function (err, reply) {
			if (err) callback(err);

			// update where we keep track of the sequence number:
			var mID = 0;
			if (reply) {
				mID = parseInt(reply, 10);
			}
			redisC.hset("channels:currentMessageID", room, mID+1);

			// alter the message object itself
			msg.mID = mID;

			// store the message
			redisC.hset("chatlog:" + room, mID, JSON.stringify(msg), function (err, reply) {
				if (err) callback(err);

				// return the altered message object
				callback(null, msg);
			});
		});
	}

	function createWebshot (data, room) {
		if (config.chat &&
			config.chat.webshot_previews &&
			config.chat.webshot_previews.enabled) {
			// strip out other things the client is doing before we attempt to render the web page
			var urls = data.body.replace(REGEXES.urls.image, "")
								.replace(REGEXES.urls.youtube,"")
								.match(REGEXES.urls.all_others);
			var from_mID = data.mID;
			if (urls) {
				for (var i = 0; i < urls.length; i++) {

					var randomFilename = parseInt(Math.random()*9000,10).toString() + ".jpg"; // also guarantees we store no more than 9000 webshots at any time

					(function (url, fileName) { // run our screenshotting routine in a self-executing closure so we can keep the current filename & url
						var output = SANDBOXED_FOLDER + "/" + fileName,
							pageData;

						DEBUG && console.log("Processing ", urls[i]);
						var screenshotter = spawn(config.chat.webshot_previews.PHANTOMJS_PATH,
							['./PhantomJS-Screenshot.js', url, output],
							{
								cwd: __dirname,
								timeout: 30*1000 // after 30s, we'll consider phantomjs to have failed to screenshot and kill it
							});

						screenshotter.stdout.on('data', function (data) {
							try {
								pageData = JSON.parse(data.toString()); // explicitly cast it, who knows what type it is having come from a process
							} catch (e) { // if the result was not JSON'able
								// DEBUG && console.log(data); // contains all kinds of garbage like script errors
							}
							
						});
						screenshotter.stderr.on('data', function (data) {
							// DEBUG && console.log('screenshotter stderr: ' + data.toString());
						});
						screenshotter.on("exit", function (data) {
							// DEBUG && console.log('screenshotter exit: ' + data.toString());
							if (pageData) {
								pageData.webshot = urlRoot() + 'sandbox/' + fileName;
								pageData.original_url = url;
								pageData.from_mID = from_mID;
							}

							sio.of(CHATSPACE).in(room).emit('webshot:' + room, pageData);
						});
					})(urls[i], randomFilename); // call our closure with our random filename
				}
			}
		}
	}

	var ChatServer = require('./AbstractServer.js').AbstractServer(sio, redisC, EventBus, Channels, ChannelModel);

	ChatServer.initialize({
		name: "ChatServer",
		SERVER_NAMESPACE: CHATSPACE,
		events: {
			"help": function (namespace, socket, channel, client, data) {
				var room = channel.get("name");
				socket.in(room).emit('chat:' + room, serverSentMessage({
					body: "Please view the README for more information at https://github.com/qq99/echoplexus"
				}, room));
			},
      "roll": function (namespace, socket, channel, client, data) {
        var room = channel.get("name");
        var dice = "d20";
        var diceResult = 0;
        
        if (data.dice !== '') {
					dice = data.dice.substring(0, data.dice.length).trim();
          
          var diceType = 20;
          var diceMultiple = 1;
          
          if(dice.match(/^(\d|)(d|)(2|3|4|6|8|12|20|100)$/)){
            if(dice.match(/^(\d|)d/)){
              diceType = dice.replace(/(\dd|)(d|)/, "").trim();
              
              if(dice.match(/(\d)d/)){
                diceMultiple = dice.replace(/d(2|3|4|6|8|12|20|100)$/, "").trim(); 
              }
            }else{
              diceType = dice;
            }
            
          }else{
            dice = "d20"; 
          }
          
          if(diceMultiple > 1){
            var diceEach = "";
            for (var i=0; i<diceMultiple; i++){
              
              roll = (1 + Math.floor(Math.random()* diceType));
              diceResult = diceResult + roll;
              if(i === 0){
                diceEach = " " + roll + " ";
              }else{
                diceEach = diceEach + " + " + roll + " ";
              }
              
            }
            diceResult = diceEach + " = " + diceResult
          }else{
            diceResult = (1 + Math.floor(Math.random()* diceType));
          }
          
        }else{
          diceResult = (1 + Math.floor(Math.random()* 20));
        }
        
  			socket.in(room).broadcast.emit('chat:' + room, serverSentMessage({
    				body: client.get("nick") + " rolled " + dice + " dice: " + diceResult
  			}, room));

        socket.in(room).emit('chat:' + room, serverSentMessage({
            body: "You rolled " + dice + " dice: " + diceResult
        }, room));

      },
      "chown": function (namespace, socket, channel, client, data) {
				var room = channel.get("name");

				if (typeof data.key === "undefined") return;

				channel.assumeOwnership(client, data.key, function (err, response) {
					if (err) {
						socket.in(room).emit('chat:' + room, serverSentMessage({
							body: err.message
						}, room));
						return;
					}

					client.becomeChannelOwner();

					socket.in(room).emit('chat:' + room, serverSentMessage({
						body: response
					}, room));
					publishUserList(channel);
				});
			},
			"chmod": function (namespace, socket, channel, client, data) {
				var room = channel.get("name"),
					bestowables = client.get("permissions").canBestow,
					startOfUsername = data.body.indexOf(' '),
					username,
					perms = data.body.substring(0, (startOfUsername === -1) ? data.body.length : startOfUsername);

				if (startOfUsername !== -1) {
					username = data.body.substring(startOfUsername, data.body.length).trim();
				} else {
					username = null;
				}

				if (!bestowables) {
					emitGenericPermissionsError(socket, client);
					return;
				}

				perms = _.compact(_.uniq(perms.replace(/([+-])/g, " $1").split(' ')));

				var errors = [],
					successes = [],
					permsToSave = {};
				for (var i = 0; i < perms.length; i++) {
					var perm = perms[i],
						permValue = (perm.charAt(0) === "+"),
						permName = perm.replace(/[+-]/g, '');

					// we can't bestow it, continue to next perm
					if (!bestowables[permName]) {
						errors.push(perm);
						continue;
					} else {
						successes.push(perm);
					}

					permsToSave[permName] = permValue;
				}

				if (successes.length) {
					if (username) { // we're setting a perm on the user object
						var targetClients = channel.clients.where({nick: username}); // returns an array
						if (typeof targetClients !== "undefined" &&
							targetClients.length) {

							// send the pm to each client matching the name
							_.each(targetClients, function (targetClient) {
								console.log("currently",targetClient.get("permissions").toJSON());
								console.log("setting", permsToSave);
								targetClient.get("permissions").set(permsToSave);
								console.log("now",targetClient.get("permissions").toJSON());
								targetClient.persistPermissions();
								targetClient.socketRef.in(room).emit('chat:' + room, serverSentMessage({
									body: client.get("nick") + " has set your permissions to [" + successes + "]."
								}, room));
							});

							socket.in(room).emit('chat:' + room, serverSentMessage({
								body: "You've successfully set [" + successes + "] on " + username
							}, room));
						} else {
							// some kind of error message
						}
					} else { // we're setting a channel perm
						channel.permissions.set(permsToSave);
						channel.persistPermissions();

						socket.in(room).emit('chat:' + room, serverSentMessage({
							body: "You've successfully set [" + successes + "] on the channel."
						}, room));
						socket.in(room).broadcast.emit('chat:' + room, serverSentMessage({
							body: client.get("nick") + " has set [" + successes + "] on the channel."
						}, room));
					}
				}

				if (errors.length) {
					socket.in(room).emit('chat:' + room, serverSentMessage({
						body: "The permissions [" + errors + "] don't exist or you can't bestow them."
					}, room));
				}
			},
			"make_public": function (namespace, socket, channel, client, data) {
				var room = channel.get("name");

				if (!channel.hasPermission(client, "canMakePublic")) {
					emitGenericPermissionsError(socket, client);
					return;
				}

				channel.makePublic(function (err, response) {
					if (err) {
						socket.in(room).emit('chat:' + room, serverSentMessage({
							body: err.message
						}, room));
						return;
					}
					
					broadcast(socket, channel, "This channel is now public.");
				});
			},
			"make_private": function (namespace, socket, channel, client, data) {
				var room = channel.get("name");

				if (!channel.hasPermission(client, "canMakePrivate")) {
					emitGenericPermissionsError(socket, client);
					return;
				}

				channel.makePrivate(data.password, function (err, response) {
					if (err) {
						socket.in(room).emit('chat:' + room, serverSentMessage({
							body: err.message
						}, room));				
						return;
					}
					
					broadcast(socket, channel, "This channel is now private.  Please remember your password.");
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

				var newName = data.nick,
					prevName = client.get("nick");

				client.set("identified", false, {silent: true});
				client.unset("encrypted_nick");

				if (typeof data.encrypted_nick !== "undefined") {
					newName = "-";
					client.set("encrypted_nick", data.encrypted_nick);
				}

				if (newName === "") {
					socket.in(room).emit('chat:' + room, serverSentMessage({
						body: "You may not use the empty string as a nickname.",
						log: false
					}, room));
					return;
				}

				client.set("nick", newName);

				ack();
			},
			"topic": function (namespace, socket, channel, client, data) {
				var room = channel.get("name");
				
				if (!channel.hasPermission(client, "canSetTopic")) {
					emitGenericPermissionsError(socket, client);
					return;
				}

				channel.setTopic(data);
				
				sio.of(CHATSPACE).in(room).emit("topic:" + room, {
					body: channel.get("topicObj")
				});
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

				if (!channel.hasPermission(client, "canPullLogs")) {
					emitGenericPermissionsError(socket, client);
					return;
				}

				redisC.hmget("chatlog:" + room, data.requestRange, function (err, reply) {
					if (err) throw err;
					// emit the logged replies to the client requesting them
					socket.in(room).emit('chat:batch:' + room, _.without(reply, null));
				});
			},
			"chat:idle": function (namespace, socket, channel, client, data) {
				var room = channel.get("name");

				client.set({
					idle: true,
					idleSince: Number(new Date())
				});
			},
			"chat:unidle": function (namespace, socket, channel, client, data) {
				var room = channel.get("name");

				client.set({
					idle: false,
					idleSince: null
				});
			},
			"private_message": function (namespace, socket, channel, client, data) {
				var targetClients;
				var room = channel.get("name");

				if (!channel.hasPermission(client, "canSpeak")) {
					emitGenericPermissionsError(socket, client);
					return;
				}

				// only send a message if it has a body & is directed at someone
				if (data.body) {
					data.color = client.get("color").toRGB();
					data.nickname = client.get("nick");
					data.encrypted_nick = client.get("encrypted_nick");
					data.timestamp = Number(new Date());
					data.type = "private";
					data.class = "private";
					data.identified = client.get("identified");

					// find the sockets of the clients matching the nick in question
					// we must do more work to match ciphernicks
					if (data.encrypted || data.ciphernicks) {
						targetClients = [];

						// O(nm) if pm'ing everyone, most likely O(n) in the average case
						_.each(data.ciphernicks, function (ciphernick) {
							for (var i = 0; i < channel.clients.length; i++) {
								var encryptedNick = channel.clients.at(i).get("encrypted_nick");

								if (encryptedNick &&
									encryptedNick["ct"] === ciphernick) {

									targetClients.push(channel.clients.at(i));
								}
							}
						});

						delete data.ciphernicks; // no use sending this to other clients
					} else { // it wasn't encrypted, just find the regular directedAt
						targetClients = channel.clients.where({nick: data.directedAt}); // returns an array
					}

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

				});
			},
			"chat": function (namespace, socket, channel, client, data) {
				var room = channel.get("name");

				if (!channel.hasPermission(client, "canSpeak")) {
					emitGenericPermissionsError(socket, client);
					return;
				}

				if (config.chat &&
					config.chat.rate_limiting &&
					config.chat.rate_limiting.enabled) {
					
					if (client.tokenBucket.rateLimit()) return;
				}

				if (data.body) {
					data.color = client.get("color").toRGB();
					data.nickname = client.get("nick");
					data.encrypted_nick = client.get("encrypted_nick");
					data.timestamp = Number(new Date());
					data.identified = client.get("identified");

					// store in redis
					storePersistent(data, room, function (err, msg) {
						var mID = msg.mID;

						socket.in(room).broadcast.emit('chat:' + room, msg);
						socket.in(room).emit('chat:' + room, _.extend(msg, {
							you: true
						}));

						createWebshot(msg, room);

						if (err) {
							console.log("Was unable to persist a chat message", err.message, msg);
						}

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

									// TODO: does not output the right nick while encrypted, may not be necessary as this functionality might change (re: GPG/PGP)
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

									} else { // ident'd
										client.set("identified", true);
										socket.in(room).emit('chat:' + room, serverSentMessage({
											class: "identity ack",
											body: "You are now identified for " + nick
										}, room));
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


									client.set("identified", true);
									socket.in(room).emit('chat:' + room, serverSentMessage({
										body: "You have registered your nickname.  Please remember your password."
									}, room));

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

			},
			"left_call": function (namespace, socket, channel, client) {
				client.set("inCall", false);

			},
			"unsubscribe": function (namespace, socket, channel, client) {
				channel.clients.remove(client);
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
			var room = channel.get("name");
			DEBUG && console.log("Client joined ", room);
			subscribeSuccess(socket, client, channel);

			// channel.initialized is inelegant (since it clearly has been)
			// and other modules might use it.
			// hotfix for now, real fix later
			if (channel.initialized === false) {
				// only bind these once *ever*
				channel.clients.on("change", function (changed) {
					clientChanged(socket, channel, changed);
				});
				channel.clients.on("remove", function (removed) {
					clientRemoved(socket, channel, removed);
				});
				channel.initialized = true;

				// listen for file upload events
				EventBus.on("file_uploaded:" + room, function (data) {
					// check to see that the uploader someone actually in the channel
					var fromClient = channel.clients.findWhere({id: data.from_user});

					if (typeof fromClient !== "undefined" &&
						fromClient !== null) {

						var uploadedFile = serverSentMessage({
							body: fromClient.get("nick") + " just uploaded: " + data.path
						}, room);

						storePersistent(uploadedFile, room, function (err, msg) {
							if (err) {
								console.log("Error persisting a file upload notification to redis", err.message, msg);
							}

							sio.of(CHATSPACE).in(room).emit("chat:" + room, msg);
						});


					}
				});
			}
		}
	});
};
