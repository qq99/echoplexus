exports.CodeServer = function (sio, redisC, EventBus, Channels, ChannelModel) {
	
	var CODESPACE = "/code",
		config = require('./config.js').Configuration,
		Client = require('../client/client.js').ClientModel,
		Clients = require('../client/client.js').ClientsCollection;

	var DEBUG = config.DEBUG;

	var CodeServer = require('./AbstractServer.js').AbstractServer(sio, redisC, EventBus, Channels, ChannelModel);

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

	var codeCaches = {};

	CodeServer.initialize({
		name: "CodeServer",
		SERVER_NAMESPACE: CODESPACE,
		events: {
			"code:cursorActivity": function (namespace, socket, channel, client, data) {
				socket.in(namespace).broadcast.emit('code:cursorActivity:' + namespace, {
					cursor: data.cursor,
					id: client.get("id")
				});
			},
			"code:change": function (namespace, socket, channel, client, data) {
				var codeCache = spawnCodeCache(namespace);

				data.timestamp = Number(new Date());
				codeCache.add(data, client);
				socket.in(namespace).broadcast.emit('code:change:' + namespace, data);
			},
			"code:full_transcript": function (namespace, socket, channel, client, data) {
				var codeCache = spawnCodeCache(namespace);

				codeCache.set(data.code);
				socket.in(namespace).broadcast.emit('code:sync:' + namespace, data);
			}
		}
	});

	function spawnCodeCache (ns) {
		if (typeof codeCaches[ns] !== "undefined") {
			DEBUG && console.log("note: Aborted spawning a code that already exists", ns);
			return codeCaches[ns];
		}
		cc = new CodeCache(ns);
		codeCaches[ns] = cc;
		
		setInterval(cc.syncFromClient, 1000*30);

		return cc;
	}

	CodeServer.start({
		error: function (err, socket, channel, client) {
			if (err) {
				DEBUG && console.log("CodeServer: ", err);
				return;
			}
		},
		success: function (namespace, socket, channel, client) {
			var cc = spawnCodeCache(namespace);
			
			socket.in(namespace).emit('code:authoritative_push:' + namespace, cc.syncToClient());
		}
	});

};