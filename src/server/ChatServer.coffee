_                = require("underscore")
config           = require('./config.coffee').Configuration
AbstractServer   = require('./AbstractServer.coffee').AbstractServer
Client           = require('../client/client.js.coffee').ClientModel
Clients          = require('../client/client.js.coffee').ClientsCollection

async            = require("async")
spawn            = require("child_process").spawn

fs               = require("fs")
crypto           = require("crypto")
uuid             = require("node-uuid")
ApplicationError = require("./Error.js.coffee")
redisC           = require("./RedisClient.coffee").RedisClient()
REGEXES          = require("../client/regex.js.coffee").REGEXES
DEBUG            = config.DEBUG
GithubWebhook    = require("./GithubWebhookIntegration.coffee")
EventBus         = require("./EventBus.coffee").EventBus()

# 3rd party
openpgp          = require("../../lib/openpgpjs/openpgp.min.js")

# Extensions     :
Dice             = require("./extensions/dice.coffee").Dice

module.exports.ChatServer = class ChatServer extends AbstractServer
	name: "ChatServer"
	namespace: "/chat"

	editMessage: (namespace, socket, channel, client, data) ->
		if config.chat?.edit?
			return if not config.chat.edit.enabled
			return if not config.chat.edit.allow_unidentified && not client.get("fingerprint")

		room = channel.get("name")
		mID = parseInt(data.mID, 10)
		editResultCallback = (err, msg) =>
			if err
				socket.in(room).emit("chat:#{room}", @serverSentMessage({
					body: err.message
				}, room))
				return
			else
				socket.in(room).broadcast.emit("chat:edit:#{room}", msg)
				socket.in(room).emit("chat:edit:#{room}", _.extend(msg, {
					you: true
				}))

		if _.indexOf(client.mIDs, mID) != -1
			@updatePersistedMessage(room, mID, data, editResultCallback)
		else # attempt to use the client's identity token, if it exists & if it matches the one stored with the chatlog object
			redisC.hget "chatlog:identity_tokens:#{room}", mID, (err, reply) ->
				throw err if err

				if client.identity_token == reply
					@updatePersistedMessage(room, mID, data, editResultCallback)

	updatePersistedMessage: (room, mID, newMessage, callback) ->
		mID = parseInt(mID, 10)
		newBody = newMessage.body
		newEncryptedText = undefined
		alteredMsg = undefined

		# get the pure message
		redisC.hget "chatlog:#{room}", mID, (err, reply) ->
			throw err  if err
			alteredMsg = JSON.parse(reply) # parse it

			# is it within an allowable time period?  if not set, allow it
			if config.chat and config.chat.edit and config.chat.edit.maximum_time_delta
				oldestPossible = Number(new Date()) - config.chat.edit.maximum_time_delta # now - delta
				callback new Error("Message too old to be edited")  if alteredMsg.timestamp < oldestPossible
			# trying to edit something too far back in time
			alteredMsg.body = newBody # alter it
			alteredMsg.encrypted = newMessage.encrypted  if typeof newMessage.encrypted isnt "undefined"

			# overwrite the old message with the altered chat message
			redisC.hset "chatlog:#{room}", mID, JSON.stringify(alteredMsg), (err, reply) ->
				throw err  if err
				callback null, alteredMsg

	urlRoot: ->
		if config.host.USE_PORT_IN_URL
			config.host.SCHEME + "://" + config.host.FQDN + ":" + config.host.PORT + "/"
		else
			config.host.SCHEME + "://" + config.host.FQDN + "/"

	serverSentMessage: (msg, room) ->
		_.extend msg,
			nickname: config.features.SERVER_NICK
			type: "SYSTEM"
			timestamp: Number(new Date())
			room: room

	publishUserList: (channel) ->
		room = channel.get("name")
		authenticatedClients = channel.clients.where({authenticated: true})

		@sio.of(@namespace).in(room).emit("userlist:#{room}", {
			users: authenticatedClients,
			room: room
		})

	clientChanged: (socket, channel, changedClient) ->
		room = channel.get("name")
		@sio.of(@namespace).in(room).emit("client:changed:#{room}", changedClient.toJSON())

	clientRemoved: (socket, channel, changedClient) ->
		room = channel.get("name")
		@sio.of(@namespace).in(room).emit("client:removed:#{room}", changedClient.toJSON())

	emitGenericPermissionsError: (socket, client) ->
		room = client.get("room")

		socket.in(room).emit("chat:#{room}", @serverSentMessage({
			body: "I can't let you do that, " + client.get("nick"),
			log: false
		}))

	broadcast: (socket, channel, message) ->
		room = channel.get("name")

		@sio.of(@namespace).in(room).emit("chat:#{room}", @serverSentMessage({
			body: message
		}, room))

	initializeChannel: (room, socket, channel) ->
		# only bind these once *ever*
		channel.clients.on "change", (changed) =>
			@clientChanged(socket, channel, changed)

		channel.clients.on "remove", (removed) =>
			@clientRemoved(socket, channel, removed)

		channel.initialized = true

		EventBus.on "github:postreceive:#{room}", (data) =>
			msg = @serverSentMessage({
				body: data
			}, room)
			msg.nickname = "GitHub"
			msg.trustworthiness = "limited"

			@storePersistent msg, room, =>
				@sio.of(@namespace).in(room).emit("chat:#{room}", msg)

		# listen for file upload events
		EventBus.on "file_uploaded:#{room}", (data) =>
			# check to see that the uploader someone actually in the channel
			fromClient = channel.clients.findWhere({id: data.from_user})

			if fromClient?
				uploadedFile = @serverSentMessage({
					body: fromClient.get("nick") + " just uploaded: " + data.path
				}, room)

				@storePersistent uploadedFile, room, (err, msg) =>
					if err
						console.log("Error persisting a file upload notification to redis", err.message, msg)

					@sio.of(@namespace).in(room).emit("chat:#{room}", msg)

	subscribeSuccess: (effectiveRoom, socket, channel, client, data) ->
		room = channel.get("name")

		# channel.initialized is inelegant (since it clearly has been)
		# and other modules might use it.
		# hotfix for now, real fix later
		@initializeChannel(room, socket, channel) if !channel.initialized


		# add to server's list of authenticated clients
		# channel.clients.add(client)

		# tell the newly connected client know the ID of the latest logged message
		redisC.hget "channels:currentMessageID", room, (err, reply) ->
			throw err if err
			socket.in(room).emit("chat:currentID:#{room}", {
				mID: reply,
				room: room
			})

		# tell the newly connected client the topic of the channel:
		socket.in(room).emit("topic:#{room}", @serverSentMessage({
			body: channel.get("topicObj"),
			log: false,
		}, room))

		# let the knewly joined know their ID
		socket.in(room).emit("client:id:#{room}", {
			room: room,
			id: client.get("id")
		})

		client.antiforgery_token = uuid.v4()
		socket.in(room).emit("antiforgery_token:#{room}", {
			antiforgery_token: client.antiforgery_token
		})

		@publishUserList(channel)

	subscribeError: (err, socket, channel, client, data) ->
		room = channel.get("name")

		if err and not err instanceof ApplicationError.AuthenticationError
			socket.in(room).emit("chat:#{room}", @serverSentMessage({
				body: err.message
			}, room))

			console.log("ChatServer: ", err)
		return

	storePersistent: (msg, room, callback) ->

		# store in redis
		redisC.hget "channels:currentMessageID", room, (err, reply) ->
			callback err  if err

			# update where we keep track of the sequence number:
			mID = 0
			mID = parseInt(reply, 10)  if reply
			redisC.hset "channels:currentMessageID", room, mID + 1

			# alter the message object itself
			msg.mID = mID

			if config.chat?.log == false
				callback null, msg
				return

			# store the message
			redisC.hset "chatlog:#{room}", mID, JSON.stringify(msg), (err, reply) ->
				callback err  if err

				# return the altered message object
				callback null, msg

	destroyChannelLogs: (room, callback) ->

		redisC.del "chatlog:#{room}", (err, reply) ->
			callback err if err

			redisC.hset "channels:currentMessageID", room, 0, (err, reply) ->
				callback err if err

				console.log "Chatlog deleted for #{room}"
				callback null

	generateAuthenticationToken: (socket, client, channel) ->
		token = uuid.v4()
		room  = channel.get("name")
		nick  = client.get("nick")

		redisC.setex "token:authentication:#{token}", 30*24*60*60, room, (err, reply) =>

			socket.in(room).emit("token:#{room}", {
				token: token
				type: "authentication"
			})

	createWebshot: (body, from_mID, room) ->
		if config.chat?.webshot_previews?.enabled
			# strip out other things the client is doing before we attempt to render the web page
			urls = body.replace(REGEXES.urls.image, "")
							.replace(REGEXES.urls.youtube,"")
							.match(REGEXES.urls.all_others)

			if urls
				for url in urls

					randomFilename = parseInt(Math.random()*9000,10).toString() + ".jpg" # also guarantees we store no more than 9000 webshots at any time

					((url, fileName) => # run our screenshotting routine in a self-executing closure so we can keep the current filename & url
						output = config.SANDBOXED_FOLDER + "/" + fileName
						console.log("Processing ", url)
						pageData = null

						screenshotter = spawn(config.chat.webshot_previews.PHANTOMJS_PATH,
							['./PhantomJS-Screenshot.js.coffee', url, output],
							{
								cwd: __dirname
								timeout: 30*1000 # after 30s, we'll consider phantomjs to have failed to screenshot and kill it
							})

						screenshotter.stdout.on 'data', (data) ->
							try
								pageData = JSON.parse(data.toString()) if data # explicitly cast it, who knows what type it is having come from a process
							catch e # if the result was not JSON'able
								console.log e

						screenshotter.stderr.on 'data', (data) ->
							console.log data

						screenshotter.on "exit", (data) =>
							# DEBUG && console.log('screenshotter exit: ' + data.toString())
							if pageData
								pageData.webshot = @urlRoot() + 'sandbox/' + fileName
								pageData.original_url = url
								pageData.from_mID = from_mID

							@sio.of(@namespace).in(room).emit("webshot:#{room}", pageData)
					)(url, randomFilename) # call our closure with our random filename

	unauthenticatedEvents: ["join_private"]
	events:
		"help": (namespace, socket, channel, client, data) ->
			room = channel.get("name")
			socket.in(room).emit("chat:#{room}", @serverSentMessage({
				body: "Please view the README for more information at https://github.com/qq99/echoplexus"
			}, room))

		"roll": (namespace, socket, channel, client, data) ->
			room = channel.get("name")
			dice = data.dice

			result = Dice::formatResult Dice::parseAndRollDice(dice)

			socket.in(room).broadcast.emit("chat:#{room}", @serverSentMessage({
				body: "#{client.get("nick")} #{result}"
			}, room))

			socket.in(room).emit("chat:#{room}", @serverSentMessage({
				body: "You #{result}"
			}, room))


		"chown": (namespace, socket, channel, client, data) ->
			room = channel.get("name")

			return if !data.key?

			channel.assumeOwnership client, data.key, (err, response) =>
				if err
					socket.in(room).emit("chat:#{room}", @serverSentMessage({
						body: err.message
					}, room))
					return

				client.becomeChannelOwner()

				socket.in(room).emit("chat:#{room}", @serverSentMessage({
					body: response
				}, room))
				@publishUserList(channel)

		"chmod": (namespace, socket, channel, client, data) ->
			room = channel.get("name")
			bestowables = client.get("permissions").canBestow
			startOfUsername = data.body.indexOf(' ')
			permStart = startOfUsername
			permStart = data.body.length if permStart == -1
			perms = data.body.substring(0, permStart)

			if startOfUsername != -1
				username = data.body.substring(startOfUsername, data.body.length).trim()
			else
				username = null

			if !bestowables
				@emitGenericPermissionsError(socket, client)
				return

			perms = _.compact(_.uniq(perms.replace(/([+-])/g, " $1").split(' ')))

			errors = []
			successes = []
			permsToSave = {}

			for perm in perms
				permValue = (perm.charAt(0) == "+")
				permName = perm.replace(/[+-]/g, '')

				# we can't bestow it, continue to next perm
				if not bestowables[permName]
					errors.push(perm)
					continue
				else
					successes.push(perm)

				permsToSave[permName] = permValue

			if (successes.length)
				if (username) # we're setting a perm on the user object
					targetClients = channel.clients.where({nick: username}) # returns an array
					if targetClients?.length

						# send the pm to each client matching the name
						_.each targetClients, (targetClient) =>
							console.log("currently",targetClient.get("permissions").toJSON())
							console.log("setting", permsToSave)
							targetClient.get("permissions").set(permsToSave)
							console.log("now",targetClient.get("permissions").toJSON())
							targetClient.persistPermissions()
							targetClient.socketRef.in(room).emit("chat:#{room}", @serverSentMessage({
								body: client.get("nick") + " has set your permissions to [#{successes}]."
							}, room))

						socket.in(room).emit("chat:#{room}", @serverSentMessage({
							body: "You've successfully set [#{successes}] on #{username}"
						}, room))
					else
						# some kind of error message
				else # we're setting a channel perm
					channel.permissions.set(permsToSave)
					channel.persistPermissions()

					socket.in(room).emit("chat:#{room}", @serverSentMessage({
						body: "You've successfully set [#{successes}] on the channel."
					}, room))
					socket.in(room).broadcast.emit("chat:#{room}", @serverSentMessage({
						body: client.get("nick") + " has set [#{successes}] on the channel."
					}, room))

			if errors.length
				socket.in(room).emit("chat:#{room}", @serverSentMessage({
					body: "The permissions [#{errors}] don't exist or you can't bestow them."
				}, room))

		"make_public": (namespace, socket, channel, client, data) ->
			room = channel.get("name")

			if !channel.hasPermission(client, "canMakePublic")
				@emitGenericPermissionsError(socket, client)
				return

			channel.makePublic (err, response) =>
				if err
					socket.in(room).emit("chat:#{room}", @serverSentMessage({
						body: err.message
					}, room))
					return

				@broadcast(socket, channel, "This channel is now public.")

		"make_private": (namespace, socket, channel, client, data) ->
			room = channel.get("name")

			if !channel.hasPermission(client, "canMakePrivate")
				@emitGenericPermissionsError(socket, client)
				return

			channel.makePrivate data.password, (err, response) =>
				if err
					socket.in(room).emit("chat:#{room}", @serverSentMessage({
						body: err.message
					}, room))
					return

				@broadcast socket, channel, "This channel is now private.  Please remember your password."

		"join_private": (namespace, socket, channel, client, data, ack) ->
			room = channel.get("name")

			channel.authenticate client, data, (err, response) =>
				if err
					if err.message instanceof ApplicationError.AuthenticationError
						if err.message == "Incorrect password."
							# let everyone currently in the room know that someone failed to join it
							socket.in(room).broadcast.emit("chat:#{room}", @serverSentMessage({
								class: "identity",
								body: client.get("nick") + " just failed to join the room."
							}, room))
							ack(err)

					# let the joiner know what went wrong:
					ack?("Wrong password")
				else
					ack?(null)
					@generateAuthenticationToken(socket, client, channel) if !data.token

		"nickname": (namespace, socket, channel, client, data, ack) ->
			room = channel.get("name")

			newName = data.nick
			prevName = client.get("nick")

			client.unset "encrypted_nick"
			if data.encrypted_nick?
				newName = "-"
				client.set "encrypted_nick", data.encrypted_nick

			if newName == ""
				socket.in(room).emit("chat:#{room}", @serverSentMessage({
					body: "You may not use the empty string as a nickname.",
					log: false
				}, room))
				return

			client.set("nick", newName)

			ack()

		"topic": (namespace, socket, channel, client, data) ->
			room = channel.get("name")

			if !channel.hasPermission(client, "canSetTopic")
				@emitGenericPermissionsError(socket, client)
				return

			channel.setTopic(data)

			@sio.of(@namespace).in(room).emit("topic:#{room}", {
				body: channel.get("topicObj")
			})

		"destroy_logs": (namespace, socket, channel, client, data) ->
			room = channel.get("name")

			if !channel.hasPermission(client, "canDeleteLogs")
				@emitGenericPermissionsError(socket, client)
				return

			@destroyChannelLogs room, (err, result) =>
				if err
					@broadcast(socket, channel, "Error destroying chatlogs for #{room}.")
				else
					@broadcast(socket, channel, "Chatlogs for #{room} have been erased.")

		"chat:history_request": (namespace, socket, channel, client, data) ->
			room = channel.get("name")
			jsonArray = []

			if !channel.hasPermission(client, "canPullLogs")
				@emitGenericPermissionsError(socket, client)
				return

			redisC.hmget "chatlog:#{room}", data.requestRange, (err, reply) ->
				throw err if err
				# emit the logged replies to the client requesting them
				socket.in(room).emit("chat:batch:#{room}", _.without(reply, null))

		"chat:idle": (namespace, socket, channel, client, data) ->
			room = channel.get("name")

			client.set
				idle: true,
				idleSince: Number(new Date())

		"chat:unidle": (namespace, socket, channel, client, data) ->
			room = channel.get("name")
			client.set
				idle: false
				idleSince: null

		"directed_message": (namespace, socket, channel, client, data, ack) ->
			room = channel.get("name")

			data.color          = client.get("color").toRGB()
			data.nickname       = client.get("nick")
			data.encrypted_nick = client.get("encrypted_nick")
			data.timestamp      = Number(new Date())
			echo_id             = data.echo_id
			delete data.echo_id

			# O(n^2) in worst possible case
			for c in channel.clients.models
				for key, value of data.directed_to
					fail = false
					compare_to = c.get(key) # the client value we're looking at
					#console.log "Comparing #{compare_to} to #{value}"
					if value instanceof Array # can be a single message directed to a bunch of people
						for item in value
							if compare_to != item
								fail = true
					else if compare_to != value # or a single message directed to a single person
						fail = true

				#console.log "Fail = #{fail}"

				if !fail
					c.socketRef.emit("private_message:#{room}", data)

			ack?(_.extend(data, {
				echo_id: echo_id
			}))

		"user:set_color": (namespace, socket, channel, client, data) ->
			room = channel.get("name")

			client.get("color").parse data.userColorString, (err) =>
				if err
					socket.in(room).emit("chat:#{room}", @serverSentMessage({
						type: "SERVER",
						body: err.message
					}, room))
					return
				client.trigger("change", client) # setting sub-model won't trigger change on main, so we fire it manually

		"set_public_key": (namespace, socket, channel, client, data) ->
			if data.armored_public_key
				client.set('armored_public_key', data.armored_public_key)
				try
					dearmored = openpgp.key.readArmored(data.armored_public_key)
					fingerprint = dearmored.keys[0]?.primaryKey?.getFingerprint()
					client.set('fingerprint', fingerprint)
				catch
					console.log 'Error reading armored public key'
			else
				client.unset('armored_public_key')

			@publishUserList(channel)

		"chat": (namespace, socket, channel, client, data, ack) ->
			room = channel.get("name")

			if !channel.hasPermission(client, "canSpeak")
				@emitGenericPermissionsError(socket, client)
				return

			if config.chat?.rate_limiting?.enabled
				return if client.tokenBucket.rateLimit() # spam limiting

			if data.type == "edit"
				@editMessage(namespace, socket, channel, client, data)
				return

			if data.body
				data.color = client.get("color").toRGB()
				data.nickname = client.get("nick")
				data.encrypted_nick = client.get("encrypted_nick")
				data.timestamp = Number(new Date())

				# don't need to persist the ack_id
				echo_id = data.echo_id
				delete data.echo_id

				# store in redis
				@storePersistent data, room, (err, msg) =>
					mID = msg.mID

					socket.in(room).broadcast.emit "chat:#{room}", msg
					ack?(_.extend(msg, {
						echo_id: echo_id
					}))

					body = msg.body
					try # not to use the entire armored PGP when we're scanning body for webshot-able URLs
						message = openpgp.cleartext.readArmored(body)
						body = message.text if message?.text?

					@createWebshot(body, msg.mID, room)

					if err
						console.log("Was unable to persist a chat message", err.message, msg)

					# store the message ID transiently on the client object itself, for anonymous editing
					client.mIDs = [] if !client.mIDs?
					client.mIDs.push(mID)

					# is there an edit token associated with this client?  if so, persist that so he can edit the message later
					if client.identity_token
						redisC.hset "chatlog:identity_tokens:#{room}", mID, client.identity_token, (err, reply) ->
							throw err if err

		"in_call": (namespace, socket, channel, client) ->
			client.set("inCall", true)

		"left_call": (namespace, socket, channel, client) ->
			client.set("inCall", false)

		"add_github_webhook": (namespace, socket, channel, client, data) ->
			room = channel.get("name")
			repoUrl = data.repoUrl

			return if !repoUrl?

			if !channel.hasPermission(client, "canSetGithubPostReceiveHooks")
				@emitGenericPermissionsError(socket, client)
				return

			GithubWebhook.allowRepository room, repoUrl, (err, token) =>
				if err
					socket.in(room).emit("chat:#{room}", @serverSentMessage({
						body: err.toString()
					}, room))
				else
					socket.in(room).emit("chat:#{room}", @serverSentMessage({
						body: "Github webhook integrations are now enabled for #{repoUrl}.  Please set up your hook to point to: #{@urlRoot()}api/github/postreceive/#{token}"
					}, room))


		"unsubscribe": (namespace, socket, channel, client) ->
			channel.clients.remove(client)


