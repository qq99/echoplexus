config 					= require('./config.js').Configuration
AbstractServer 	= require('./AbstractServer.js').AbstractServer
Client 					= require('../client/client.js').ClientModel
Clients 				= require('../client/client.js').ClientsCollection
DEBUG 					= config.DEBUG


module.exports.CodeCache = class CodeCache

	constructor: (namespace) ->
		@currentState = ""
		@namespace = ""
		@namespace = namespace if namespace?
		@mruClient = undefined
		@ops = []

  set: (state) ->
    @currentState = state
    @ops = []

  add: (op, client) ->
    @mruClient = client
    @ops.push op

  syncFromClient: ->
    return if !mruClient?
    @mruClient.socketRef.emit "code:request:#{@namespace}"

  syncToClient: ->
    start: @currentState
    ops: @ops

  remove: (client) ->
    @mruClient = null if mruClient is client


module.exports.CodeServer = class CodeServer extends AbstractServer

	name: "CodeServer"
	namespace: "/code"
	initialize:
		@codeCaches = {}

	events:
		"code:cursorActivity": (namespace, socket, channel, client, data) ->
			room = channel.get("name")
			socket.in(room).broadcast.emit "code:cursorActivity:#{room}",
				cursor: data.cursor,
				id: client.get("id")

		"code:change": (namespace, socket, channel, client, data) ->
			room = channel.get("name")
			codeCache = spawnCodeCache room

			data.timestamp = Number(new Date())
			codeCache.add data, client
			socket.in(room).broadcast.emit "code:change:#{room}", data

		"code:full_transcript": (namespace, socket, channel, client, data) ->
			room = channel.get("name")
			codeCache = spawnCodeCache room

			codeCache.set data.code
			socket.in(room).broadcast.emit "code:sync:#{room}", data

	spawnCodeCache = (ns) ->
	  if typeof @codeCaches[ns] isnt "undefined"
	    #DEBUG and console.log("note: Aborted spawning a code that already exists", ns)
	    return @codeCaches[ns]

	  cc = new module.exports.CodeCache(ns)
	  @codeCaches[ns] = cc
	  setInterval cc.syncFromClient, 1000 * 30 # need something more elegant than this..
	  cc
