exports.DrawingServer = function (sio, redisC, EventBus, auth, Channels, ChannelModel) {
	
	var DRAWSPACE = "/draw",
		config = require('./config.js').Configuration,
		Client = require('../client/client.js').ClientModel,
		Clients = require('../client/client.js').ClientsCollection,
		_ = require('underscore');

	var DEBUG = config.DEBUG;

	var DrawServer = require('./AbstractServer.js').AbstractServer(sio, redisC, EventBus, auth, Channels, ChannelModel);

	DrawServer.initialize({
		name: "DrawServer",
		SERVER_NAMESPACE: DRAWSPACE,
		events: {
			"draw:line": function (socket, channel, client, data) {
				var room = channel.get("name");

				channel.replay.push({
					type: "draw:line",
					data: data
				});

				socket.in(room).broadcast.emit('draw:line:' + room, _.extend(data,{
					cid: client.cid
				}));
			},
			"trash": function (socket, channel, client, data) {
				var room = channel.get("name");

				channel.replay = [];
				socket.in(room).broadcast.emit('trash:' + room, data);
			}
		}
	});

	DrawServer.start({
		error: function (err, socket, channel, client) {
			if (err) {
				console.log("DrawServer: ", err);
				return;
			}
		},
		success: function (socket, channel, client) {
			var room = channel.get("name");
		
			// socket.join(room);
			// play back what has happened
			_.each(channel.replay, function (datum) {
				socket.emit(datum.type + ":" + room, datum.data);
			});
		}
	});



};