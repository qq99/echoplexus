exports.CodeServer = function (sio, redisC, EventBus, auth) {
	
	var CODESPACE = "/code",
		config = require('./config.js').Configuration,
		Client = require('../client/client.js').ClientModel,
		Clients = require('../client/client.js').ClientsCollection;

	var DEBUG = config.DEBUG;

	function CodeCache (namespace) {
		var currentState = "",
			namespace = (typeof namespace !== "undefined") ? namespace : "",
			mruClient,
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
				if (typeof mruClient === "undefined") return;

				mruClient.socketRef.emit('code:request:' + namespace);
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

	function Channel (name) {
		this.name = name;
		this.clients = new Clients();
		this.codeCache = new CodeCache(name);
		return this;
	}

	var channels = {};

	function publishUserList (room) {
		if (channels[room] === undefined) {
			console.warn("Publishing userlist of a channel that doesn't exist...", room);
			return;
		}
		sio.of(CODESPACE).in(room).emit('userlist:' + room, {
			users: channels[room].clients.toJSON(),
			room: room
		});
	}

	var CODE = sio.of(CODESPACE).on('connection', function (socket) {
		console.log("sockID:", socket.id);
		socket.on("subscribe", function (data) {
			var client,
				unauthenticatedEvents = [],
				room = data.room,
				subchannel = data.subchannel,
				channelKey = room + ":" + subchannel;

			// get the channel
			var channel = channels[channelKey];
			if (typeof channel === "undefined") { // start a new channel if it doesn't exist
				channel = new Channel(channelKey);
				channels[channelKey] = channel;
			}

			var codeEvents = {
				"code:cursorActivity": function (data) {
					DEBUG && console.log("code:cursorActivity", data);
					socket.in(channelKey).broadcast.emit('code:cursorActivity:' + channelKey, {
						cursor: data.cursor,
						cid: client.cid
					});
				},
				"code:change": function (data) {
					DEBUG && console.log("code:change", data);
					data.timestamp = Number(new Date());
					channel.codeCache.add(data, client);
					socket.in(channelKey).broadcast.emit('code:change:' + channelKey, data);
				},
				"code:full_transcript": function (data) {
					DEBUG && console.log("code:full_transcript", data);
					channel.codeCache.set(data.code);
					socket.in(channelKey).broadcast.emit('code:sync:' + channelKey, data);
				}
			};

			// EventBus.on("nickset." + socket.id, function (data) {
			// 	client.set("nick", data.nick);
			// 	client.set("color", data.color);
			// 	publishUserList(channelKey);
			// });

			function bindEvents () {
				// client must exist!
				// bind all chat events:
				_.each(codeEvents, function (method, eventName) {
					var authFiltered = _.wrap(method, function (meth) {
						var margs = arguments;
						// DEBUG && console.log(arguments);
						// DEBUG && console.log(eventName, client.get("room"), !_.contains(unauthenticatedEvents, eventName));
						socket.get("authStatus", function (err, authStatus) {
							console.log("prefilter", room, socket.id, socket.authStatus)
							if (!authStatus[room] &&
								!_.contains(unauthenticatedEvents, eventName)) {
								return;
							}
							var args = Array.prototype.slice.call(margs).splice(1); // first arg is the function itself
							meth.apply(socket, args); // not even once.
						});
					});
					socket.on(eventName + ":" + channelKey, authFiltered);
				});
			}



			auth.authenticate(socket, room, "", function (err, response) {
				
				client = new Client({
					room: room
				});
				client.socketRef = socket;

				bindEvents();
			});


			setInterval(channel.codeCache.syncFromClient, 1000*30);

			EventBus.on("authentication:success", function (data) {
				if (data.channelName === room) {
					console.log(channelKey, " recv'd auth success");
					socket.join(channelKey);	

					socket.in(channelKey).emit('code:authoritative_push:' + channelKey, channel.codeCache.syncToClient());

					channel.clients.add(client);
				}
			});

			socket.on("unsubscribe", function () {
				if (typeof client !== "undefined") {
					channel.clients.remove(client);
				}

				publishUserList(channelKey);
			});

			socket.on("disconnect", function () {
				if (typeof client !== "undefined") {
					channel.clients.remove(client);
				}

				publishUserList(channelKey);
			});
		});

	});

};