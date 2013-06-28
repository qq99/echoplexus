exports.UserServer = function (sio, redisC, EventBus, Channels, ChannelModel) {

	var USERSPACE = "/user",
		config = require('./config.js').Configuration,
		_ = require('underscore');

	var DEBUG = config.DEBUG;

	var UserServer = require('./AbstractServer.js').AbstractServer(sio, redisC, EventBus, Channels, ChannelModel);

	UserServer.initialize({
		name: "UserServer",
		SERVER_NAMESPACE: USERSPACE,
		events: {
			"put": function (namespace, socket, channel, client, data, ack) {
				var room = channel.get("name");

				client.set(data.fields, {trigger: true});
				ack();
			},
			"get": function (namespace, socket, channel, client, data) {
				var room = channel.get("name");

			}
		}
	});

	UserServer.start({
		error: function (err, socket, channel, client) {
			if (err) {
				DEBUG && console.log("UserServer: ", err);
				return;
			}
		},
		success: function (namespace, socket, channel, client) {
			var room = channel.get("name");
		}
	});

};