exports.CodeServer = (sio, redisC, EventBus, Channels, ChannelModel) ->

	CODESPACE = "/code"
	config = require('./config.js').Configuration
	Client = require('../client/client.js').ClientModel
	Clients = require('../client/client.js').ClientsCollection
	DEBUG = config.DEBUG

	CodeServer = require('./AbstractServer.js').AbstractServer(sio, redisC, EventBus, Channels, ChannelModel)

	CodeCache = (namespace) ->
	  currentState = ""
	  namespace = (if (typeof namespace isnt "undefined") then namespace else "")
	  mruClient = undefined
	  ops = []
	  set: (state) ->
	    currentState = state
	    ops = []

	  add: (op, client) ->
	    mruClient = client
	    ops.push op

	  syncFromClient: ->
	    return  if typeof mruClient is "undefined"
	    mruClient.socketRef.emit "code:request:" + namespace

	  syncToClient: ->
	    start: currentState
	    ops: ops

	  remove: (client) ->
	    mruClient = null  if mruClient is client

	codeCaches = {}

	CodeServer.initialize({
		name: "CodeServer"
		SERVER_NAMESPACE: CODESPACE
		events:
			"code:cursorActivity": (namespace, socket, channel, client, data) ->
				socket.in(namespace).broadcast.emit('code:cursorActivity:' + namespace, {
					cursor: data.cursor,
					id: client.get("id")
				});
			"code:change": (namespace, socket, channel, client, data) ->
				codeCache = spawnCodeCache(namespace);

				data.timestamp = Number(new Date());
				codeCache.add(data, client);
				socket.in(namespace).broadcast.emit('code:change:' + namespace, data);
			"code:full_transcript": (namespace, socket, channel, client, data) ->
				codeCache = spawnCodeCache(namespace);

				codeCache.set(data.code);
				socket.in(namespace).broadcast.emit('code:sync:' + namespace, data);
	});

	spawnCodeCache = (ns) ->
	  if typeof codeCaches[ns] isnt "undefined"
	    DEBUG and console.log("note: Aborted spawning a code that already exists", ns)
	    return codeCaches[ns]
	  cc = new CodeCache(ns)
	  codeCaches[ns] = cc
	  setInterval cc.syncFromClient, 1000 * 30
	  cc

	CodeServer.start(
		error: (err, socket, channel, client) ->
			if err
				DEBUG && console.log("CodeServer: ", err);
				return;
		success: (namespace, socket, channel, client) ->
			cc = spawnCodeCache(namespace);

			socket.in(namespace).emit('code:authoritative_push:' + namespace, cc.syncToClient());
	);
