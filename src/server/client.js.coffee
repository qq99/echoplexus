_               = require("underscore")
uuid            = require("node-uuid")
config          = require("../server/config.coffee").Configuration
Client          = require("../client/client.js").ClientModel
redisC          = require("./RedisClient.coffee").RedisClient()
PermissionModel = require("./PermissionModel.coffee").ClientPermissionModel

module.exports.TokenBucket = class TokenBucket
  # from: http://stackoverflow.com/questions/667508/whats-a-good-rate-limiting-algorithm

  constructor: () ->
    @rate = config.chat.rate_limiting.rate # unit: # messages
    @per = config.chat.rate_limiting.per # unit: milliseconds
    @allowance = @rate # unit: # messages
    @last_check = Number(new Date()) # unit: milliseconds

  rateLimit: ->
    current = Number(new Date())
    time_passed = current - @last_check
    @last_check = current
    @allowance += time_passed * (@rate / @per)
    @allowance = @rate  if @allowance > @rate # throttle
    if @allowance < 1.0
      true # discard message, "true" to rate limiting
    else
      @allowance -= 1.0
      false # allow message, "false" to rate limiting

module.exports.ServerClient = class ServerClient extends Client

  initialize: ->
    _.bindAll.apply(_, [this].concat(_.functions(this)))
    @on "change:identified", (data) =>
      @loadMetadata()
      @setIdentityToken (err) =>
        throw err  if err
        @getPermissions()

    @on "change:encrypted_nick", (client, changed) =>
      # changed is either undefined, or an object representing {ciphertext,salt,iv}
      if changed # added a ciphernick
        @set "ciphernick", changed.ct
      else
        @unset "ciphernick"

    Client::initialize.apply this, arguments
    @set "permissions", new PermissionModel()

    # set a good global identifier
    @set "id", uuid.v4() if uuid?

    if (config?.chat?.rate_limiting?.enabled)
      @tokenBucket = new TokenBucket

  setIdentityToken: (callback) ->
    room = @get("room")
    nick = @get("nick")

    # check to see if a token already exists for the user
    redisC.hget "identity_token:#{room}", nick, (err, reply) =>
      callback err  if err
      unless reply # if not, make a new one
        token = uuid.v4()
        redisC.hset "identity_token:#{room}", nick, token, (err, reply) => # persist it
          throw err  if err
          @identity_token = token # store it on the client object
          callback null

      else
        token = reply
        @identity_token = token # store it on the client object
        callback null

  hasPermission: (permName) ->
    @get("permissions").get permName

  becomeChannelOwner: ->
    console.log @get "permissions"
    @get("permissions").upgradeToOperator()
    @set "operator", true # TODO: add a way to send client data on change events

  getPermissions: ->
    room = @get("room")
    nick = @get("nick")
    identity_token = @identity_token;

    console.log room, nick, identity_token

    return if !identity_token?

    redisC.hget "permissions:#{room}", "#{nick}:#{identity_token}", (err, reply) =>
      throw err if err
      if reply
        stored_permissions = JSON.parse(reply)
        @get("permissions").set stored_permissions

  persistPermissions: ->
    return if @get("identified")

    room = @get("room")
    nick = @get("nick")
    identity_token = @identity_token

    redisC.hset "permissions:#{room}", "#{nick}:#{identity_token}", JSON.stringify(@get("permissions").toJSON())

  metadataToArray: ->
    data = []
    _.each @supported_metadata, (field) =>
      data.push field
      data.push @get(field)

    data

  saveMetadata: ->
    if @get("identified")
      room = @get("room")
      nick = @get("nick")
      data = @metadataToArray()
      redisC.hmset "users:room:#{nick}", data, (err, reply) ->
        throw err  if err
        callback null

  loadMetadata: ->
    if @get("identified")
      room = @get("room")
      nick = @get("nick")
      fields = {}
      redisC.hmget "users:room:#{nick}", @supported_metadata, (err, reply) =>
        throw err  if err

        # console.log("metadata:", reply);
        i = 0

        while i < reply.length
          fields[@supported_metadata[i]] = reply[i]
          i++

        # console.log(fields);
        @set fields,
          trigger: true

        reply # just in case
