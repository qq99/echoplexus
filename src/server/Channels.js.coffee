Backbone            = require("backbone")
_                   = require("underscore")
async               = require("async")
crypto              = require("crypto")
ApplicationError    = require("./Error.js.coffee")
Clients             = require("../client/client.js.coffee").ClientsCollection
config              = require("./config.coffee").Configuration
EventBus            = require("./EventBus.coffee").EventBus()
PermissionModel     = require("./PermissionModel.coffee").ChannelPermissionModel
redisC              = require("./RedisClient.coffee").RedisClient()
ServerClientModel   = require("./client.js.coffee").ServerClient

module.exports.ChannelModel = class ChannelModel extends Backbone.Model
  isPrivate: ->
    @get "private"

module.exports.ServerChannelModel = class ServerChannelModel extends ChannelModel

  defaults:
    name: ""
    topic: null
    private: null
    hasOwner: null # no one can become an owner until the status of this is resolved

  initialize: ->
    _.bindAll.apply(_, [this].concat(_.functions(this)))
    @clients = new Clients()
    @replay = []
    @call = {}
    @codeCaches = {}
    @getOwner()
    @getTopic()
    @permissions = new PermissionModel()
    @getPermissions()

  getTopic: () ->
    room = @get("name")
    redisC.hget "topic", room, (err, reply) =>
      @set "topicObj", reply # for socket

      # for API:
      if reply and reply.encrypted_topic
        @set "topic", reply.encrypted_topic.ct
      else
        @set "topic", reply

  setTopic: (data) ->
    if data.encrypted_topic
      topicObj  = JSON.stringify(data.encrypted_topic)
      topic     = data.encrypted_topic.ct
    else
      topicObj  = data.topic
      topic     = data.topic

    @set "topic", topic # transient
    @set "topicObj", topicObj # "
    redisC.hset "topic", @get("name"), topicObj # persist

    topic

  hasPermission: (client, permName) ->
    perm = undefined

    # first check user perms
    perm = client.hasPermission(permName)

    if perm is null

      # if not set, check channel perms
      perm = @permissions.get(permName)
      perm = false  if perm is null # if not set, default is deny

    perm

  getPermissions: ->
    room = @get("name")

    redisC.hget "permissions:#{room}", "channel_perms", (err, reply) =>
      throw err  if err
      if reply
        stored_permissions = JSON.parse(reply)
        @permissions.set stored_permissions

  persistPermissions: ->
    room = @get("name")
    redisC.hset "permissions:#{room}", "channel_perms", JSON.stringify(@permissions.toJSON())

  getOwner: ->
    channelName = @get("name")

    # only query the hasOwner once per lifetime
    redisC.hget "channels:" + channelName, "owner_derivedKey", (err, reply) =>
      if reply # channel has an owner
        @set "hasOwner", true
      else # no owner
        @set "hasOwner", false

  assumeOwnership: (client, key, callback) ->
    channelName = @get("name")
    if @get("hasOwner") is false
      @setOwner key, (err, result) ->
        throw err  if err
        callback null, result

    else if @get("hasOwner") is true

      # get the salt and salted+hashed password
      async.parallel
        salt: (callback) ->
          redisC.hget "channels:" + channelName, "owner_salt", callback
        password: (callback) ->
          redisC.hget "channels:" + channelName, "owner_derivedKey", callback
      , (err, stored) ->
        callback err  if err
        crypto.pbkdf2 key, stored.salt, 4096, 256, (err, derivedKey) ->
          callback err  if err
          if derivedKey.toString() isnt stored.password # auth failure
            callback new ApplicationError.AuthenticationError("Incorrect password.")
          else # auth success
            callback null, "You have proven that you are the channel owner."

  setOwner: (key, callback) ->
    channelName = @get("name")

    # attempt to make the channel private with the supplied password
    try
      # generate 256 random bytes to salt the password
      crypto.randomBytes 256, (err, buf) =>
        throw err  if err # crypto failed
        salt = buf.toString()

        # run 4096 iterations producing a 256 byte key
        crypto.pbkdf2 key, salt, 4096, 256, (err, derivedKey) =>
          throw err  if err # crypto failed
          async.parallel [(callback) ->
            redisC.hset "channels:" + channelName, "owner_salt", salt, callback
          , (callback) ->
            redisC.hset "channels:" + channelName, "owner_derivedKey", derivedKey.toString(), callback
          ], (err, reply) =>
            throw err  if err
            @set "hasOwner", true
            callback null, "You are now the channel owner." # everything worked and the room is now private



    catch e # catch any crypto or persistence error, and return a general error string
      callback new Error("An error occured while attempting to set a channel owner.")

  isPrivate: (callback) ->
    channelName = @get("name")

    # if we've cached the redis result, return that
    if @get("private") isnt null
      callback null, @get("private")
    else # otherwise we don't know the state of isPrivate, so we query the db
      # only query the isPrivate once per lifetime
      redisC.hget "channels:" + channelName, "isPrivate", (err, reply) =>
        callback err  if err # redis error
        if reply is "true" # channel is private
          @set "private", true
          callback null, true
        else # channel is public
          @set "private", false
          callback null, false

  makePrivate: (channelPassword, callback) ->
    # Attempts to make a channel private
    # Throws user friendly errors if:
    # - it's already private
    # - the new channel password is the empty string
    # - crypto or persistence fails
    channelName = @attributes.name
    callback new Error("You must supply a password to make the channel private.")  if channelPassword is ""
    @isPrivate (err, privateChannel) =>
      callback err  if err
      if privateChannel
        callback new Error(channelName + " is already private")
      else

        # attempt to make the channel private with the supplied password
        try

          # generate 256 random bytes to salt the password
          crypto.randomBytes 256, (err, buf) =>
            throw err  if err # crypto failed
            salt = buf.toString()

            # run 4096 iterations producing a 256 byte key
            crypto.pbkdf2 channelPassword, salt, 4096, 256, (err, derivedKey) =>
              throw err  if err # crypto failed
              async.parallel [(callback) ->
                redisC.hset "channels:" + channelName, "isPrivate", true, callback
              , (callback) ->
                redisC.hset "channels:" + channelName, "salt", salt, callback
              , (callback) ->
                redisC.hset "channels:" + channelName, "password", derivedKey.toString(), callback
              ], (err, reply) =>
                throw err  if err
                @set "private", true
                callback null, true # everything worked and the room is now private



        catch e # catch any crypto or persistence error, and return a general error string
          callback new Error("An error occured while attempting to make the channel private.")

  makePublic: (callback) ->
    # Attempts to make a channel public
    # Throws user friendly errors if:
    # - it's already public
    # - persistence fails
    channelName = @attributes.name
    @isPrivate (err, privateChannel) =>
      callback err  if err
      callback new Error(channelName + " is already public")  unless privateChannel
      async.parallel [(callback) ->
        redisC.hdel "channels:" + channelName, "isPrivate", callback
      , (callback) ->
        redisC.hdel "channels:" + channelName, "salt", callback
      , (callback) ->
        redisC.hdel "channels:" + channelName, "password", callback
      ], (err, reply) =>
        callback new Error("An error occured while attempting to make the channel public.")  if err
        @set "private", false
        callback null, true # everything worked and the room is now private

  isSocketAlreadyAuthorized: (socket) ->
    channelName = @attributes.name;

    if socket.authStatus?
      socket.authStatus[channelName];

  getSocketAuthObject: (socket, callback) ->
    socket.get "authStatus", (err, authObject) ->
      callback err if err
      authObject = {} if authObject is null
      callback null, authObject

  authenticationSuccess: (client) ->
    channelName = @attributes.name
    socket = client.socketRef
    @getSocketAuthObject socket, (err, authStatus) ->
      throw err  if err
      authStatus[channelName] = true
      socket.set "authStatus", authStatus, ->
        client.set "authenticated", true
        client.trigger "authenticated", client

  authenticate: (client, data, callback) ->
    password = data.password
    token = data.token
    socket = client.socketRef
    channelName = @attributes.name

    # preempt any expensive checks
    callback null, true  if @isSocketAlreadyAuthorized(socket, channelName)
    @isPrivate (err, privateChannel) =>
      callback new Error("An error occured while attempting to join the channel.")  if err
      if privateChannel

        if password
          @authenticateViaPassword(client, password, callback)
        else if token
          @authenticateViaToken(client, token, callback)
        else
          callback new ApplicationError.AuthenticationError("This channel is private.")

      else
        @authenticationSuccess client
        callback null, true

  authenticateViaPassword: (client, password, callback) ->
    channelName = @attributes.name

    # get the salt and salted+hashed password
    async.parallel {
      salt: (callback) ->
        redisC.hget "channels:" + channelName, "salt", callback
      password: (callback) ->
        redisC.hget "channels:" + channelName, "password", callback
    }, (err, stored) =>
      callback err  if err

      crypto.pbkdf2 password, stored.salt, 4096, 256, (err, derivedKey) =>
        callback err  if err
        if derivedKey.toString() isnt stored.password # auth failure
          callback new ApplicationError.AuthenticationError("Incorrect password.")
        else # auth success
          @authenticationSuccess client
          callback null, true

  authenticateViaToken: (client, token, callback) ->
    room = @attributes.name

    redisC.get "token:authentication:#{token}", (err, reply) =>
      throw err if err

      if reply and reply == room
        @authenticationSuccess client
        callback null, true
      else
        callback new ApplicationError.AuthenticationError("Incorrect token.")

module.exports.ChannelsCollection = class ChannelsCollection extends Backbone.Collection
  initialize: (instances, options) ->
    _.bindAll.apply(_, [this].concat(_.functions(this)))
    _.extend this, options

    # since we're also the authentication provider, we must
    # respond to any requests that wish to know if our client (HTTP/XHR)
    # has successfully authenticated
    EventBus.on "has_permission", (clientQuery, callback) =>

      # find the room he's purportedly in
      inChannel = @findWhere(name: clientQuery.channel)
      if typeof inChannel is "undefined" or inChannel is null
        callback 403, "That channel does not exist."
        return

      # find the client matching the ID he purports to be
      fromClient = inChannel.clients.findWhere(id: clientQuery.from_user)
      if typeof fromClient is "undefined" or fromClient is null
        callback 403, "You are not a member of that channel."
        return

      # find whether his antiforgery token matches
      if fromClient.antiforgery_token isnt clientQuery.antiforgery_token
        callback 403, "Please don't spoof requests."
        return

      # find whether he's authenticated for the channel in question
      unless fromClient.get("authenticated")
        callback 403, "You are not authenticated for that channel."
        return

      # finally, find whether he has permission to perform the requested operation:
      unless inChannel.hasPermission(fromClient, clientQuery.permission)
        callback 403, "You do not have permission to perform this operation."
        return

      # he passed all auth checks:
      callback null
