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
    client = new irc.Client 'chat.freenode.net', 'qq99',
        channels: ['#foo']
        debug: true

    client.addListener 'error', (message) ->
        console.log('error: ', message)

    client.addListener 'pm', (from, message) ->
        console.log(from + ' => ME: ' + message)

    client.addListener 'message', (from, to, message) ->
      console.log(from, to, message)
      socket.emit "chat:/chat.freenode.net#foo",
        body: message
        nickname: from

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
      console.log data