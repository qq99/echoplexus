exports.CodeServer = function (sio, redisC) {
	
	var CODESPACE = "/code",
		config = require('./config.js').Configuration,
		Client = require('../client/client.js').ClientModel,
		Clients = require('../client/client.js').ClientsCollection;

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

	var CODE = sio.of(CODESPACE).on('connection', function (socket) {
		socket.on("subscribe", function (data) {
			var client,
				room = data.room,
				subchannel = data.subchannel,
				channelKey = room + ":" + subchannel;

			var codeEvents = {
				"code:cursorActivity": function (data) {
					console.log("code:cursorActivity", data);
					socket.in(channelKey).broadcast.emit('code:cursorActivity:' + channelKey, {
						cursor: data.cursor,
						id: client.cid
					});
				},
				"code:change": function (data) {
					console.log("code:change", data);
					data.timestamp = Number(new Date());
					channel.codeCache.add(data, client);
					socket.in(channelKey).broadcast.emit('code:change:' + channelKey, data);
				},
				"code:full_transcript": function (data) {
					console.log("code:full_transcript", data);
					channel.codeCache.set(data.code);
					socket.in(channelKey).broadcast.emit('code:sync:' + channelKey, data);
				}
			};

			console.log("codeclient connected on", channelKey);
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
			channel.clients.push(client);

			// bind all chat events:
			_.each(codeEvents, function (value, key) {
				socket.on(key + ":" + channelKey, value);
			});

			setInterval(channel.codeCache.syncFromClient, 1000*30);

			socket.in(channelKey).emit('code:authoritative_push:' + channelKey, channel.codeCache.syncToClient());
		});

	});

};