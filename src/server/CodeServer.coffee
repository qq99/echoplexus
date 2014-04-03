config          = require('./config.coffee').Configuration
AbstractServer  = require('./AbstractServer.coffee').AbstractServer
Client          = require('../client/client.js.coffee').ClientModel
Clients         = require('../client/client.js.coffee').ClientsCollection
DEBUG           = config.DEBUG


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
  constructor: ->
    @codeCaches = {}
    super

  subscribeError: (err, socket, channel, client) ->
    if err and not err instanceof ApplicationError.AuthenticationError
      console.log("CodeServer: ", err)
  subscribeSuccess: (effectiveRoom, socket, channel, client) ->
    cc = @spawnCodeCache(effectiveRoom)
    socket.in(effectiveRoom).emit("code:authoritative_push:#{effectiveRoom}", cc.syncToClient());

  events:
    "code:cursorActivity": (namespace, socket, channel, client, data) ->
      socket.in(namespace).broadcast.emit "code:cursorActivity:#{namespace}",
        cursor: data.cursor,
        id: client.get("id")

    "code:change": (namespace, socket, channel, client, data) ->
      codeCache = @spawnCodeCache namespace

      data.timestamp = Number(new Date())
      codeCache.add data, client
      socket.in(namespace).broadcast.emit "code:change:#{namespace}", data

    "code:full_transcript": (namespace, socket, channel, client, data) ->
      codeCache = @spawnCodeCache namespace

      codeCache.set data.code
      socket.in(namespace).broadcast.emit "code:sync:#{namespace}", data

  spawnCodeCache: (ns) ->
    if @codeCaches[ns]?
      #DEBUG and console.log("note: Aborted spawning a code that already exists", ns)
      return @codeCaches[ns]

    cc = new CodeCache(ns)
    @codeCaches[ns] = cc
    setInterval cc.syncFromClient, 1000 * 30 # need something more elegant than this..
    cc
