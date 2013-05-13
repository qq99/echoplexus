exports.DrawingServer = function (sio, redisC, EventBus) {
	
	var DRAWSPACE = "/draw",
		config = require('./config.js').Configuration,
		Client = require('../client/client.js').ClientModel,
		Clients = require('../client/client.js').ClientsCollection;

	var DEBUG = config.DEBUG;

	function Channel (name) {
		this.clients = new Clients();
		return this;
	}

	var channels = {};

	var DRAW = sio.of(DRAWSPACE).on('connection', function (socket) {
		socket.on("subscribe", function (data) {
			var client,
				room = data.room,
				channelKey = room;

			var drawEvents = {
				"draw:line": function (data) {
					// DEBUG && console.log("draw:line", data);
					socket.in(channelKey).broadcast.emit('draw:line:' + channelKey, data);
				}
			};

			DEBUG && console.log("drawclient connected on", channelKey);
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

			// bind all draw events:
			_.each(drawEvents, function (value, key) {
				socket.on(key + ":" + channelKey, value);
			});

			socket.on("unsubscribe", function () {
				channel.clients.remove(client);
			});

			socket.on("disconnect", function () {
				channel.clients.remove(client);
			});
		});

	});

};