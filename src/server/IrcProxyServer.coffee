ApplicationError = require("./Error.js.coffee")
versions         = require('./version.coffee')
_                = require('underscore')
AbstractServer   = require('./AbstractServer.coffee').AbstractServer
Client           = require('../client/client.js').ClientModel
Clients          = require('../client/client.js').ClientsCollection
config           = require('./config.coffee').Configuration
irc              = require("irc")
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
      irc_room: data.irc_options.room
      irc_server: data.irc_options.server

    ircClient = new irc.Client client.get("irc_server"), 'echoplexion',
      channels: [client.get("irc_room")]
      userName: 'echoplexus using nodebot'
      realName: 'echoplexus IRC proxy'
      debug: true

    if !ircClient.clients
      ircClient.clients = new Backbone.Collection

    client.ircClient = ircClient # associate this client instance with this socket

    ircClient.addListener 'error', (message) ->
        console.log('error: ', message)

    ircClient.addListener 'names', (room, names) =>
      names = Object.keys(names)
      names = for name in names
        {nick: name}
      ircClient.clients.set(names, {silent: true})
      @publishUserList(socket, channel, client)

    ircClient.addListener 'nick', (oldNick, newNick, channels, message) =>
      ircClient.clients.findWhere({nick: oldNick}).set("nick", newNick)
      @publishUserList(socket, channel, client)

    ircClient.addListener 'pm', (from, message) ->
        console.log(from + ' => ME: ' + message)

    ircClient.addListener 'message', (from, to, message) ->
      console.log(from, to, message)
      console.log 'emitting to', "chat:#{effectiveRoom}"
      socket.emit "chat:#{effectiveRoom}",
        body: message
        nickname: from
        timestamp: Number(new Date())

    ircClient.addListener 'pm', (nick, message) ->
        console.log('Got private message from %s: %s', nick, message)

    ircClient.addListener 'join', (room, nick, message) =>
      ircClient.clients.add({nick: nick})
      @publishUserList(socket, channel, client)

    ircClient.addListener 'part', (room, nick, message) =>
      ircClient.clients.remove(ircClient.clients.findWhere({nick: nick}))
      @publishUserList(socket, channel, client)

    ircClient.addListener 'kick', (channel, who, kicked_by, reason) ->
        console.log('%s was kicked from %s by %s: %s', who, channel, kicked_by, reason)

  subscribeError: (err, socket, channel, client) ->
    room = channel.get("name")

    if err and err instanceof ApplicationError.AuthenticationError
      console.log("InfoServer: ", err)
      socket.in(room).emit("private:#{room}")
    else
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

    "unsubscribe": (namespace, socket, channel, client) ->
      return if !client.ircClient
      console.log 'User left channel'
      client.ircClient.disconnect("Bye!")
      channel.clients.remove(client)