_         = require("underscore")
config    = require("./config.coffee").Configuration
Clients   = require("../client/client.js.coffee").ClientsCollection
DEBUG     = config.DEBUG

module.exports.AbstractServer = class AbstractServer
  constructor: (@sio, @channels, @ChannelModel) ->
    @Client = require("./client.js.coffee").ServerClient

  initializeClientEvents: (namespace, socket, channel, client) ->
    server = this

    # bind the events:
    _.each @events, (method, eventName) ->

      # wrap the event in an authentication filter:
      authFiltered = _.wrap(method, (meth) ->
        method_args = arguments

        return  if (client.get("authenticated") is false) and not _.contains(server.unauthenticatedEvents, eventName)

        method_args = Array::slice.call(method_args).splice(1) # first argument is the function itself
        method_args.unshift namespace, socket, channel, client
        meth.apply server, method_args # not even once.
      )

      # bind the pre-filtered event
      socket.on eventName + ":" + namespace, authFiltered

  start: (callback) ->
    server = this

    console.log @namespace

    @serverInstance = @sio.of(@namespace).on "connection", (socket) =>
      socket.on "subscribe", (data, subscribeAck) =>
        channelName = data.room
        subchannel = data.subchannel
        channelProperties = undefined
        client = undefined
        channel = undefined
        if typeof subchannel isnt "undefined"
          effectiveRoom = channelName + ":" + subchannel
        else
          effectiveRoom = channelName

        # attempt to get the channel
        channel = @channels.findWhere(name: channelName)

        # create the channel if it doesn't already exist
        if !channel?

          # create the channel
          channel = new @ChannelModel(name: channelName)
          @channels.add channel
        client = channel.clients.findWhere(sid: socket.id)

        # console.log(server.name, "c", typeof client);
        if !client?  # there was no pre-existing client
          client = new @Client
            room: channelName
            sid: socket.id

          client.socketRef = socket
          channel.clients.add client
        else # there was a pre-existing client
          socket.join effectiveRoom  if client.get("authenticated")
        client.once "authenticated", (result) =>
          DEBUG and console.log("authenticated", server.name, client.cid, socket.id, result.attributes.authenticated)
          if result.attributes.authenticated
            socket.join effectiveRoom
            callback.success.call this, effectiveRoom, socket, channel, client, data
            subscribeAck cid: client.cid  if subscribeAck isnt null and typeof (subscribeAck) isnt "undefined"
          else
            socket.leave effectiveRoom


        # attempt to authenticate on the chanenl
        channel.authenticate client, "", (err, response) =>
          server.initializeClientEvents effectiveRoom, socket, channel, client

          # let any implementing servers handle errors the way they like
          callback.error.call this, err, socket, channel, client, data  if err


        # every server shall support a disconnect handler
        socket.on "disconnect", ->

          # DEBUG && console.log("Killing (d/c) ", client.cid, " from ", channelName);
          channel.clients.remove client  if typeof client isnt "undefined"
          _.each server.events, (value, key) ->
            socket.removeAllListeners key + ":" + channelName



        # every server shall support a unsubscribe handler (user closes channel but remains in chat)
        socket.on "unsubscribe:#{effectiveRoom}", ->

          # DEBUG && console.log("Killing (left) ", client.cid, " from ", channelName);
          channel.clients.remove client  if typeof client isnt "undefined"
          _.each server.events, (value, key) ->
            socket.removeAllListeners key + ":" + channelName
