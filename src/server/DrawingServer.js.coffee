exports.DrawingServer = (sio, redisC, EventBus, Channels, ChannelModel) ->

	DRAWSPACE = "/draw"
	config = require('./config.js').Configuration
	Client = require('../client/client.js').ClientModel
	Clients = require('../client/client.js').ClientsCollection
	_ = require('underscore')

	DEBUG = config.DEBUG

	DrawServer = require('./AbstractServer.js').AbstractServer(sio, redisC, EventBus, Channels, ChannelModel)

	DrawServer.initialize({
		name: "DrawServer",
		SERVER_NAMESPACE: DRAWSPACE,
		events: {
			"draw:line": (namespace, socket, channel, client, data) ->
				room = channel.get("name")

				channel.replay.push(data)

				socket.in(room).broadcast.emit('draw:line:' + room, _.extend(data,{
					id: client.get("id")
				}))
			"trash": (namespace, socket, channel, client, data) ->
				room = channel.get("name")

				channel.replay = []
				socket.in(room).broadcast.emit('trash:' + room, data)
		}
	})

	DrawServer.start(
		error: (err, socket, channel, client) ->
			if err
				return
		success: (namespace, socket, channel, client) ->
			room = channel.get("name")

			# play back what has happened
			socket.emit("draw:replay:" + namespace, channel.replay)
	)
