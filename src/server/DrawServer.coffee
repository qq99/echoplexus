_ 							= require('underscore')
AbstractServer 	= require('./AbstractServer.coffee').AbstractServer
Client 					= require('../client/client.js').ClientModel
Clients 				= require('../client/client.js').ClientsCollection
config 					= require('./config.coffee').Configuration
DEBUG 					= config.DEBUG

module.exports.DrawServer = class DrawingServer extends AbstractServer

	name: "DrawServer"
	namespace: "/draw"

	events:
		"draw:line": (namespace, socket, channel, client, data) ->
			room = channel.get("name")

			channel.replay.push(data)

			socket.in(room).broadcast.emit "draw:line:#{room}", (_.extend data, id: client.get("id"))

		"trash": (namespace, socket, channel, client, data) ->
			room = channel.get("name")

			channel.replay = []
			socket.in(room).broadcast.emit "trash:#{room}", data
