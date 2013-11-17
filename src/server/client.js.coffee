exports.ClientStructures = (redisC, EventBus) ->
	TokenBucket = ->

	  # from: http://stackoverflow.com/questions/667508/whats-a-good-rate-limiting-algorithm
	  rate = config.chat.rate_limiting.rate # unit: # messages
	  per = config.chat.rate_limiting.per # unit: milliseconds
	  allowance = rate # unit: # messages
	  last_check = Number(new Date()) # unit: milliseconds
	  @rateLimit = ->
	    current = Number(new Date())
	    time_passed = current - last_check
	    last_check = current
	    allowance += time_passed * (rate / per)
	    allowance = rate  if allowance > rate # throttle
	    if allowance < 1.0
	      true # discard message, "true" to rate limiting
	    else
	      allowance -= 1.0
	      false # allow message, "false" to rate limiting

	_ = require("underscore")
	uuid = require("node-uuid")
	config = require("../server/config.js").Configuration
	Client = require("../client/client.js").ClientModel

	this.ServerClient = Client.extend
		initialize: =>
			@on "change:identified", (data) ->
			  self.loadMetadata()
			  self.setIdentityToken (err) ->
			    throw err  if err
			    self.getPermissions()


			Client::initialize.apply this, arguments_

			# set a good global identifier
			@set "id", uuid.v4() if uuid?

			if (config?.chat?.rate_limiting?.enabled)
				this.tokenBucket = new TokenBucket();

		setIdentityToken: (callback) =>
			self = this
			token = undefined
			room = @get("room")
			nick = @get("nick")

			# check to see if a token already exists for the user
			redisC.hget "identity_token:" + room, nick, (err, reply) ->
			  callback err  if err
			  unless reply # if not, make a new one
			    token = uuid.v4()
			    redisC.hset "identity_token:" + room, nick, token, (err, reply) -> # persist it
			      throw err  if err
			      self.identity_token = token # store it on the client object
			      callback null

			  else
			    token = reply
			    self.identity_token = token # store it on the client object
			    callback null

		hasPermission: (permName) =>
			@get("permissions").get permName

		becomeChannelOwner: =>
			@get("permissions").upgradeToOperator()
			@set "operator", true # TODO: add a way to send client data on change events

		getPermissions: =>
			room = @get("room")
			nick = @get("nick")
			identity_token = @identity_token;

			return if !identity_token?;

			redisC.hget "permissions:" + room, nick + ":" + identity_token, (err, reply) ->
			  throw err  if err
			  if reply
			    stored_permissions = JSON.parse(reply)
			    self.get("permissions").set stored_permissions

		persistPermissions: =>
			return if @get("identified")

			room = @get("room")
			nick = @get("nick")
			identity_token = @identity_token

			redisC.hset "permissions:" + room, nick + ":" + identity_token, JSON.stringify(@get("permissions").toJSON())

		metadataToArray: =>
			data = []
			_.each @supported_metadata, (field) ->
			  data.push field
			  data.push self.get(field)

			data

		saveMetadata: =>
			if @get("identified")
			  room = @get("room")
			  nick = @get("nick")
			  data = @metadataToArray()
			  redisC.hmset "users:room:" + nick, data, (err, reply) ->
			    throw err  if err
			    callback null

		loadMetadata: =>
			if @get("identified")
			  room = @get("room")
			  nick = @get("nick")
			  fields = {}
			  redisC.hmget "users:room:" + nick, @supported_metadata, (err, reply) ->
			    throw err  if err

			    # console.log("metadata:", reply);
			    i = 0

			    while i < reply.length
			      fields[self.supported_metadata[i]] = reply[i]
			      i++

			    # console.log(fields);
			    self.set fields,
			      trigger: true

			    reply # just in case
