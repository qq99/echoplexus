exports.CodeServer = function (sio, redisC, EventBus, auth, Channels) {
	
	var CODESPACE = "/code",
		config = require('./config.js').Configuration,
		Client = require('../client/client.js').ClientModel,
		Clients = require('../client/client.js').ClientsCollection;

	var DEBUG = config.DEBUG;

	var CodeServer = require('./AbstractServer.js').AbstractServer(sio, redisC, EventBus, auth);

	function publishUserList (channel) {
		var room = channel.namespace;

		sio.of(CODESPACE).in(room).emit('userlist:' + room, {
			users: channel.clients.toJSON(),
			room: room
		});
	}

	CodeServer.initialize({
		name: "CodeServer",
		SERVER_NAMESPACE: CODESPACE,
		events: {
			"code:cursorActivity": function (socket, channel, client, data) {
				var channelKey = channel.namespace;

				socket.in(channelKey).broadcast.emit('code:cursorActivity:' + channelKey, {
					cursor: data.cursor,
					cid: client.cid
				});
			},
			"code:change": function (socket, channel, client, data) {
				var channelKey = channel.namespace;

				data.timestamp = Number(new Date());
				channel.codeCache.add(data, client);
				socket.in(channelKey).broadcast.emit('code:change:' + channelKey, data);
			},
			"code:full_transcript": function (socket, channel, client, data) {
				var channelKey = channel.namespace;

				channel.codeCache.set(data.code);
				socket.in(channelKey).broadcast.emit('code:sync:' + channelKey, data);
			}
		}
	});


	CodeServer.start({
		error: function (err, socket, channel, client) {
			if (err) {
				console.log("CodeServer: ", err);
				return;
			}
		},
		success: function (socket, channel, client) {
			var ns = channel.namespace;
			
			socket.join(ns);
			
			// TODO: only do this ONCE per channel
			setInterval(channel.codeCache.syncFromClient, 1000*30);

			socket.in(ns).emit('code:authoritative_push:' + ns, channel.codeCache.syncToClient());

			channel.clients.add(client);
			publishUserList(channel);
		}
	});

};