ApplicationError = require("./Error.js.coffee")
versions         = require('./version.coffee')
_                = require('underscore')
AbstractServer   = require('./AbstractServer.coffee').AbstractServer
Client           = require('../client/client.js').ClientModel
Clients          = require('../client/client.js').ClientsCollection
config           = require('./config.coffee').Configuration
irc              = require("irc")
q                = require('q')
DEBUG            = config.DEBUG

# this server is meant to expose all manners of metadata about the host
# that is operating echoplexus
# for instance, a client could query capabilities or client versions supported
module.exports.IrcProxyServer = class IrcProxyServer extends AbstractServer

  name: "IrcProxyServer"
  namespace: "/irc"

  publishUserList: (socket, channel, client) ->
    room = channel.get("name")
    socket.in(room).emit("userlist:#{room}", {
      users: client.ircClient.clients.toJSON()
      room: room
    })

  subscribeSuccess: (effectiveRoom, socket, channel, client, data) ->
    return if !data.irc_options or !data.irc_options.room or !data.irc_options.server

    client.set
      nick: 'echoplexion'
      irc_room: data.irc_options.room
      irc_server: data.irc_options.server

    ircClient = new irc.Client client.get("irc_server"), 'echoplexion',
      channels: [client.get("irc_room")]
      userName: 'echoplexus using nodebot'
      realName: 'echoplexus IRC proxy'
      #debug: true

    if !ircClient.clients # create it once
      ircClient.clients = new Backbone.Collection

    client.ircClient = ircClient # associate this client instance with this socket

    ircClient._hasRegistered = q.defer()
    ircClient.hasRegistered = ircClient._hasRegistered.promise

    ircClient.addListener 'registered', (message) => # initial connection to server
      socket.emit "chat:#{effectiveRoom}",
        body: message.args?[1] # cnxn message
        nickname: message.server
        timestamp: Number(new Date())

      socket.emit "chat:#{effectiveRoom}",
        body: "Please wait while echoplexus connects you to your room..."
        nickname: config.features.SERVER_NICK
        type: "SYSTEM"
        timestamp: Number(new Date())

      actualNick = message.args[0] # server may override our choice!
      client.set "nick", actualNick
      @updateClientAttributes(socket, channel, client)
      

    ircClient.addListener 'error', (message) ->
        console.log('error: ', message)

    ircClient.addListener 'names', (room, names) =>
      names = _.uniq(Object.keys(names))
      names = for name in names
        if name == client.get("nick") # this works because IRC requires nicks to be unique
          {nick: name, id: client.get("id")} # inject our own ID so we don't totally clobber our own client collection state
        else # we don't have IDs or even track state of the other dudes
          {nick: name}

      ircClient.clients.set(names, {silent: true})
      @publishUserList(socket, channel, client)

    ircClient.addListener 'nick', (oldNick, newNick, channels, message) =>
      ircClient.clients.findWhere({nick: oldNick})?.set("nick", newNick)
      @publishUserList(socket, channel, client)

    ircClient.addListener 'message', (from, to, message) ->
      if to != client.get("nick")
        namespace = "chat"
        type = ""
      else
        namespace = "private_message"
        type = "private"
        message = "@#{to}: #{message}"

      socket.emit "#{namespace}:#{effectiveRoom}",
        body: message
        nickname: from
        type: type
        timestamp: Number(new Date())

    ircClient.addListener 'notice', (from = "", to, text, message) =>
      data = 
        body: text
        nickname: from
        timestamp: Number(new Date())

      if !from
        socket.emit "chat:#{effectiveRoom}", data
      else
        data.type = 'private'
        data.body = "@#{to}: #{text}"
        socket.emit "private_message:#{effectiveRoom}", data


    ircClient.addListener 'topic', (room, topic, nick, message) ->
      socket.emit "topic:#{effectiveRoom}", body: topic

    ircClient.addListener 'join', (room, nick, message) =>
      ircClient.clients.add({nick: nick})
      @publishUserList(socket, channel, client)

    ircClient.addListener 'part', (room, nick, message) =>
      ircClient.clients.remove(ircClient.clients.findWhere({nick: nick}))
      @publishUserList(socket, channel, client)

    ircClient.addListener 'kick', (room, who, kicked_by, reason = "No reason cited") ->
      socket.emit "chat:#{effectiveRoom}",
        body: "#{who} was kicked by #{kicked_by}: #{reason}"
        nickname: ""
        timestamp: Number(new Date())

    ircClient.addListener 'raw', (message) ->
      #console.log message.command
      if message.command == 'rpl_channelmodeis' # a good signal that we're ready to use the client
        ircClient._hasRegistered.resolve()  

        socket.emit "chat:#{effectiveRoom}",
          body: "Connected!"
          nickname: config.features.SERVER_NICK
          type: "SYSTEM"
          timestamp: Number(new Date())

    # let the knewly joined know their ID
    socket.emit("client:id:#{effectiveRoom}", {
      id: client.get("id")
    })

  # force an update on the connected client's representation of his own state:
  updateClientAttributes: (socket, channel, client) ->
    room = channel.get("name")
    socket.emit("client:changed:#{room}", client.attributes)

  subscribeError: (err, socket, channel, client) ->
    room = channel.get("name")

    if err
      socket.in(room).emit("chat:#{room}", @serverSentMessage({
        body: err.message
      }, room))

  events:
    "chat": (namespace, socket, channel, client, data, ack) ->
      return if !client.ircClient
      room = client.get("irc_room")
      client.ircClient.say room, data.body
      ack?(_.extend(data, {
        you: true
        nickname: client.ircClient.nick
        timestamp: Number(new Date())
      }))

    "directed_message": (namespace, socket, channel, client, data, ack) ->
      return if !data.directed_to
      room = channel.get("name")
      client.ircClient.say data.directed_to.nick, data.body
      ack?(_.extend(data, {
        nickname: client.ircClient.nick
        you: true
        timestamp: Number(new Date())
      }))

    "unsubscribe": (namespace, socket, channel, client) ->
      return if !client.ircClient
      client.ircClient.disconnect("Bye!")
      channel.clients.remove(client)

    "nickname": (namespace, socket, channel, client, data, ack) ->
      return if !client.ircClient

      nick = data.nick || "echoplexion"
      client.ircClient.hasRegistered.done =>
        client.ircClient.send "NICK", nick
        client.set "nick", nick # assume it was successful :/
        @updateClientAttributes(socket, channel, client) # force resync
        ack()