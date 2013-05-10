exports.CodeServer = function (sio, redisC, EventBus) {
	
	var CODESPACE = "/code",
		config = require('./config.js').Configuration,
		Client = require('../client/client.js').ClientModel,
		Clients = require('../client/client.js').ClientsCollection;

	var DEBUG = config.DEBUG;

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

				mruClient.socket.emit('code:request:' + namespace);
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
		socket.on("subscribe", function (data) {
			var client,
				room = data.room,
				subchannel = data.subchannel,
				channelKey = room + ":" + subchannel;

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

			DEBUG && console.log("codeclient connected on", channelKey);
			socket.leave("\"\"");
			socket.join(channelKey);

			// get the channel
			var channel = channels[channelKey];
			if (typeof channel === "undefined") { // start a new channel if it doesn't exist
				channel = new Channel(channelKey);
				channels[channelKey] = channel;
			}

			// add the new client to our internal list
			client = new Client({
				room: room
			});
			client.socket = socket;
			channel.clients.add(client);

			EventBus.on("nickset." + socket.id, function (data) {
				client.set("nick", data.nick);
				client.set("color", data.color);
				publishUserList(channelKey);
			});

			// bind all chat events:
			_.each(codeEvents, function (value, key) {
				socket.on(key + ":" + channelKey, value);
			});

			setInterval(channel.codeCache.syncFromClient, 1000*30);

			socket.in(channelKey).emit('code:authoritative_push:' + channelKey, channel.codeCache.syncToClient());

			socket.on("unsubscribe", function () {
				channel.clients.remove(client);

				publishUserList(channelKey);
			});

			socket.on("disconnect", function () {
				channel.clients.remove(client);

				publishUserList(channelKey);
			});
		});

	});

};