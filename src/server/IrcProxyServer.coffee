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

  subscribeSuccess: (effectiveRoom, socket, channel, client, data) ->
    return if !data.irc_options
    console.log data
    client.room = data.irc_options.room
    client.server = data.irc_options.server
    return if !client.room or !client.server

    client = new irc.Client client.server, 'echoplexion',
      channels: [client.room]
      userName: 'echoplexus using nodebot'
      realName: 'echoplexus IRC proxy'
      debug: true

    socket.ircClient = client # associate this client instance with this socket
    socket.ircRoom = client.room

    client.addListener 'error', (message) ->
        console.log('error: ', message)

    client.addListener 'names', (channel, nicks) ->
      console.log channel, nicks

    client.addListener 'pm', (from, message) ->
        console.log(from + ' => ME: ' + message)

    client.addListener 'message', (from, to, message) ->
      console.log(from, to, message)
      console.log 'emitting to', "chat:#{effectiveRoom}"
      socket.emit "chat:#{effectiveRoom}",
        body: message
        nickname: from
        timestamp: Number(new Date())

    client.addListener 'pm', (nick, message) ->
        console.log('Got private message from %s: %s', nick, message)

    client.addListener 'join', (channel, who) ->
        console.log('%s has joined %s', who, channel)

    client.addListener 'part', (channel, who, reason) ->
        console.log('%s has left %s: %s', who, channel, reason)

    client.addListener 'kick', (channel, who, kicked_by, reason) ->
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
      room = "#" + channel.get("name").split("#").pop()
      socket.ircClient.say room, data.body
      ack?(_.extend(data, {
        timestamp: Number(new Date())
      }))

    "unsubscribe": (namespace, socket, channel, client) ->
      console.log 'User left channel'
      socket.ircClient.disconnect("Bye!")
      channel.clients.remove(client)