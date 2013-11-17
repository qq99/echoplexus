exports.UserServer = (sio, redisC, EventBus, Channels, ChannelModel) ->
  USERSPACE = "/user"
  config = require("./config.js").Configuration
  _ = require("underscore")
  DEBUG = config.DEBUG
  UserServer = require("./AbstractServer.js").AbstractServer(sio, redisC, EventBus, Channels, ChannelModel)
  UserServer.initialize
    name: "UserServer"
    SERVER_NAMESPACE: USERSPACE
    events:
      put: (namespace, socket, channel, client, data, ack) ->
        room = channel.get("name")
        client.set data.fields,
          trigger: true

        ack()

      get: (namespace, socket, channel, client, data) ->
        room = channel.get("name")

  UserServer.start
    error: (err, socket, channel, client) ->
      if err
        DEBUG and console.log("UserServer: ", err)
        return

    success: (namespace, socket, channel, client) ->
      room = channel.get("name")
