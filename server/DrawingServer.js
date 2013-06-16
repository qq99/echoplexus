exports.DrawingServer = function (sio, redisC, EventBus, auth) {
	
	var DRAWSPACE = "/draw",
		config = require('./config.js').Configuration,
		Client = require('../client/client.js').ClientModel,
		Clients = require('../client/client.js').ClientsCollection,
		_ = require('underscore');

	var DEBUG = config.DEBUG;

	var DrawServer = require('./AbstractServer.js').AbstractServer(sio, redisC, EventBus, auth);

	DrawServer.initialize({
		SERVER_NAMESPACE: DRAWSPACE,
		events: {
			"draw:line": function (socket, channel, client, data) {
				var room = channel.name;

				channel.replay.push({
					type: "draw:line",
					data: data
				});
				socket.in(room).broadcast.emit('draw:line:' + room, _.extend(data,{
					cid: client.cid
				}));
			},
			"trash": function (socket, channel, client, data) {
				var room = channel.name;

				channel.replay = [];
				socket.in(room).broadcast.emit('trash:' + room, data);
			}
		}
	});

	DrawServer.start(function (err, socket, channel, client) {
		if (err) {
			console.log(err);
			return;
		}
		// play back what has happened
		_.each(channel.replay, function (datum) {
			socket.emit(datum.type + ":" + channelKey, datum.data);
		});
	});

};