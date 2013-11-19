_ 								= require("underscore")
config 						= require('./config.js.coffee').Configuration
AbstractServer 		= require('./AbstractServer.coffee').AbstractServer
Client 						= require('../client/client.js.coffee').ClientModel
Clients 					= require('../client/client.js.coffee').ClientsCollection

async 						= require("async")
spawn 						= require("child_process").spawn

fs 								= require("fs")
crypto 						= require("crypto")
uuid 							= require("node-uuid")
PUBLIC_FOLDER 		= __dirname + "/../public"
SANDBOXED_FOLDER 	= PUBLIC_FOLDER + "/sandbox"
ApplicationError 	= require("./Error.js.coffee")
REGEXES 					= require("../client/regex.js.coffee").REGEXES
DEBUG 						= config.DEBUG

module.exports.ChatServer = class ChatServer extends AbstractServer
	name: "ChatServer"
	namespace: "/chat"

	updatePersistedMessage: (room, mID, newMessage, callback) ->
	  mID = parseInt(mID, 10)
	  newBody = newMessage.body
	  newEncryptedText = undefined
	  alteredMsg = undefined

	  # get the pure message
	  redisC.hget "chatlog:" + room, mID, (err, reply) ->
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
	    redisC.hset "chatlog:" + room, mID, JSON.stringify(alteredMsg), (err, reply) ->
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

		sio.of(CHATSPACE).in(room).emit("userlist:#{room}", {
			users: authenticatedClients,
			room: room
		})

	clientChanged: (socket, channel, changedClient) ->
		room = channel.get("name")
		sio.of(CHATSPACE).in(room).emit("client:changed:#{room}", changedClient.toJSON())

	clientRemoved: (socket, channel, changedClient) ->
		room = channel.get("name")
		sio.of(CHATSPACE).in(room).emit("client:removed:#{room}", changedClient.toJSON())

	emitGenericPermissionsError: (socket, client) ->
		room = client.get("room")

		socket.in(room).emit("chat:#{room}", serverSentMessage({
			body: "I can't let you do that, " + client.get("nick"),
			log: false
		}))

	broadcast: (socket, channel, message) ->
		room = channel.get("name")

		sio.of(CHATSPACE).in(room).emit("chat:#{room}", serverSentMessage({
			body: message
		}, room))

	subscribeSuccess: (socket, client, channel) ->
		room = channel.get("name")

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
		socket.in(room).emit("topic:#{room}", serverSentMessage({
			body: channel.get("topicObj"),
			log: false,
		}, room))

		# let the knewly joined know their ID
		socket.in(room).emit("client:id:#{room}", {
			room: room,
			id: client.get("id")
		})

		client.antiforgery_token = uuid.v4()
		socket.in(room).emit("antiforgery_token:" + room, {
			antiforgery_token: client.antiforgery_token
		})

		publishUserList(channel)

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

	    # store the message
	    redisC.hset "chatlog:" + room, mID, JSON.stringify(msg), (err, reply) ->
	      callback err  if err

	      # return the altered message object
	      callback null, msg

	createWebshot: (data, room) ->
		if config.chat?.webshot_previews?.enabled?
			# strip out other things the client is doing before we attempt to render the web page
			urls = data.body.replace(REGEXES.urls.image, "")
							.replace(REGEXES.urls.youtube,"")
							.match(REGEXES.urls.all_others)

			from_mID = data.mID

			if urls
				for url in urls

					randomFilename = parseInt(Math.random()*9000,10).toString() + ".jpg" # also guarantees we store no more than 9000 webshots at any time

					((url, fileName) -> # run our screenshotting routine in a self-executing closure so we can keep the current filename & url
						output = SANDBOXED_FOLDER + "/" + fileName
						DEBUG && console.log("Processing ", urls[i])

						screenshotter = spawn(config.chat.webshot_previews.PHANTOMJS_PATH,
							['./PhantomJS-Screenshot.js', url, output],
							{
								cwd: __dirname
								timeout: 30*1000 # after 30s, we'll consider phantomjs to have failed to screenshot and kill it
							})

						screenshotter.stdout.on 'data', (data) ->
							try
								pageData = JSON.parse(data.toString()) # explicitly cast it, who knows what type it is having come from a process
							catch e # if the result was not JSON'able

						#screenshotter.stderr.on 'data', (data) ->

						screenshotter.on "exit", (data) ->
							# DEBUG && console.log('screenshotter exit: ' + data.toString())
							if pageData
								pageData.webshot = urlRoot() + 'sandbox/' + fileName
								pageData.original_url = url
								pageData.from_mID = from_mID

							sio.of(CHATSPACE).in(room).emit('webshot:' + room, pageData)
					)(url, randomFilename) # call our closure with our random filename

	events:
		"help": (namespace, socket, channel, client, data) ->
			room = channel.get("name")
			socket.in(room).emit('chat:' + room, serverSentMessage({
				body: "Please view the README for more information at https://github.com/qq99/echoplexus"
			}, room))

		"chown": (namespace, socket, channel, client, data) ->
			room = channel.get("name")

			return if !data.key?

			channel.assumeOwnership client, data.key, (err, response) ->
				if err
					socket.in(room).emit("chat:#{room}", serverSentMessage({
						body: err.message
					}, room))
					return

				client.becomeChannelOwner()

				socket.in(room).emit("chat:#{room}", serverSentMessage({
					body: response
				}, room))
				publishUserList(channel)

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
				emitGenericPermissionsError(socket, client)
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
						_.each targetClients, (targetClient) ->
							console.log("currently",targetClient.get("permissions").toJSON())
							console.log("setting", permsToSave)
							targetClient.get("permissions").set(permsToSave)
							console.log("now",targetClient.get("permissions").toJSON())
							targetClient.persistPermissions()
							targetClient.socketRef.in(room).emit("chat:#{room}", serverSentMessage({
								body: client.get("nick") + " has set your permissions to [#{successes}]."
							}, room))

						socket.in(room).emit("chat:#{room}", serverSentMessage({
							body: "You've successfully set [#{successes}] on #{username}"
						}, room))
					else
						# some kind of error message
				else # we're setting a channel perm
					channel.permissions.set(permsToSave)
					channel.persistPermissions()

					socket.in(room).emit("chat:#{room}", serverSentMessage({
						body: "You've successfully set [#{successes}] on the channel."
					}, room))
					socket.in(room).broadcast.emit("chat:#{room}", serverSentMessage({
						body: client.get("nick") + " has set [#{successes}] on the channel."
					}, room))

			if errors.length
				socket.in(room).emit("chat:#{room}", serverSentMessage({
					body: "The permissions [#{errors}] don't exist or you can't bestow them."
				}, room))

		"make_public": (namespace, socket, channel, client, data) ->
			room = channel.get("name")

			if !channel.hasPermission(client, "canMakePublic")
				emitGenericPermissionsError(socket, client)
				return

			channel.makePublic (err, response) ->
				if err
					socket.in(room).emit('chat:' + room, serverSentMessage({
						body: err.message
					}, room))
					return

				broadcast(socket, channel, "This channel is now public.")

		"make_private": (namespace, socket, channel, client, data) ->
			room = channel.get("name")

			if !channel.hasPermission(client, "canMakePrivate")
				emitGenericPermissionsError(socket, client)
				return

			channel.makePrivate data.password, (err, response) ->
				if err
					socket.in(room).emit('chat:' + room, serverSentMessage({
						body: err.message
					}, room))
					return

				broadcast socket, channel, "This channel is now private.  Please remember your password."

		"join_private": (namespace, socket, channel, client, data) ->
			password = data.password
			room = channel.get("name")

			channel.authenticate client, password, (err, response) ->
				if err
					if err.message instanceof ApplicationError.Authentication
						if err.message == "Incorrect password."
							# let everyone currently in the room know that someone failed to join it
							socket.in(room).broadcast.emit('chat:' + room, serverSentMessage({
								class: "identity",
								body: client.get("nick") + " just failed to join the room."
							}, room))

					# let the joiner know what went wrong:
					socket.in(room).emit('chat:' + room, serverSentMessage({
						body: err.message
					}, room))

		"nickname": (namespace, socket, channel, client, data, ack) ->
			room = channel.get("name")

			newName = data.nick
			prevName = client.get("nick")

			client.set "identified", false,
			  silent: true

			client.unset "encrypted_nick"
			if data.encrypted_nick?
			  newName = "-"
			  client.set "encrypted_nick", data.encrypted_nick

			if newName == ""
				socket.in(room).emit('chat:' + room, serverSentMessage({
					body: "You may not use the empty string as a nickname.",
					log: false
				}, room))
				return

			client.set("nick", newName)

			ack()

		"topic": (namespace, socket, channel, client, data) ->
			room = channel.get("name")

			if !channel.hasPermission(client, "canSetTopic")
				emitGenericPermissionsError(socket, client)
				return

			channel.setTopic(data)

			sio.of(CHATSPACE).in(room).emit("topic:" + room, {
				body: channel.get("topicObj")
			})

		"chat:edit": (namespace, socket, channel, client, data) ->
			if config.chat?.edit?
				return if not config.chat.edit.enabled
				return if not config.chat.edit.allow_unidentified && not client.get("identified")

			room = channel.get("name")
			mID = parseInt(data.mID, 10)
			editResultCallback = (err, msg) ->
				if err
					socket.in(room).emit('chat:' + room, serverSentMessage({
						type: "SERVER",
						body: err.message
					}, room))
					return
				else
					socket.in(room).broadcast.emit('chat:edit:' + room, msg)
					socket.in(room).emit('chat:edit:' + room, _.extend(msg, {
						you: true
					}))

			if _.indexOf(client.mIDs, mID) != -1
				updatePersistedMessage(room, mID, data, editResultCallback)
			else # attempt to use the client's identity token, if it exists & if it matches the one stored with the chatlog object
				redisC.hget "chatlog:identity_tokens:" + room, mID, (err, reply) ->
					throw err if err

					if client.identity_token == reply
						updatePersistedMessage(room, mID, data, editResultCallback)

		"chat:history_request": (namespace, socket, channel, client, data) ->
			room = channel.get("name")
			jsonArray = []

			if !channel.hasPermission(client, "canPullLogs")
				emitGenericPermissionsError(socket, client)
				return

			redisC.hmget "chatlog:#{room}", data.requestRange, (err, reply) ->
				throw err if err
				# emit the logged replies to the client requesting them
				socket.in(room).emit('chat:batch:' + room, _.without(reply, null))

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

		"private_message": (namespace, socket, channel, client, data) ->
			room = channel.get("name")

			if !channel.hasPermission(client, "canSpeak")
				emitGenericPermissionsError(socket, client)
				return

			# only send a message if it has a body & is directed at someone
			if data.body
				data.color = client.get("color").toRGB()
				data.nickname = client.get("nick")
				data.encrypted_nick = client.get("encrypted_nick")
				data.timestamp = Number(new Date())
				data.type = "private"
				data.class = "private"
				data.identified = client.get("identified")

				# find the sockets of the clients matching the nick in question
				# we must do more work to match ciphernicks
				if data.encrypted || data.ciphernicks
					targetClients = []

					# O(nm) if pm'ing everyone, most likely O(n) in the average case
					_.each data.ciphernicks, (ciphernick) ->
						for client in channel.clients
							encryptedNick = clients.at(i).get("encrypted_nick")

							if encryptedNick && encryptedNick["ct"] == ciphernick
								targetClients.push(channel.clients.at(i))

					delete data.ciphernicks # no use sending this to other clients
				else # it wasn't encrypted, just find the regular directedAt
					targetClients = channel.clients.where({nick: data.directedAt}) # returns an array

				if targetClients?.length
					# send the pm to each client matching the name
					_.each targetClients, (client) ->
						client.socketRef.emit('private_message:' + room, data)

					# send it to the sender s.t. he knows that it went through
					socket.in(room).emit('private_message:' + room, _.extend(data, {
						you: true
					}))
				else
					# some kind of error message

		"user:set_color": (namespace, socket, channel, client, data) ->
			room = channel.get("name")

			client.get("color").parse data.userColorString, (err) ->
				if err
					socket.in(room).emit('chat:' + room, serverSentMessage({
						type: "SERVER",
						body: err.message
					}, room))
					return

		"chat": (namespace, socket, channel, client, data) ->
			room = channel.get("name")

			if !channel.hasPermission(client, "canSpeak")
				emitGenericPermissionsError(socket, client)
				return

			if config.chat?.rate_limiting?.enabled
				return if client.tokenBucket.rateLimit() # spam limiting

			if data.body
				data.color = client.get("color").toRGB()
				data.nickname = client.get("nick")
				data.encrypted_nick = client.get("encrypted_nick")
				data.timestamp = Number(new Date())
				data.identified = client.get("identified")

				# store in redis
				storePersistent data, room, (err, msg) ->
					mID = msg.mID

					socket.in(room).broadcast.emit('chat:' + room, msg)
					socket.in(room).emit('chat:' + room, _.extend(msg, {
						you: true
					}))

					createWebshot(msg, room)

					if err
						console.log("Was unable to persist a chat message", err.message, msg)

					# store the message ID transiently on the client object itself, for anonymous editing
					client.mIDs = [] if !client.mIDs?
					client.mIDs.push(mID)

					# is there an edit token associated with this client?  if so, persist that so he can edit the message later
					if client.identity_token
						redisC.hset "chatlog:identity_tokens:#{room}", mID, client.identity_token, (err, reply) ->
							throw err if err

		"identify": (namespace, socket, channel, client, data) ->
			room = channel.get("name")
			nick = client.get("nick")

			try
				redisC.sismember "users:#{room}", nick, (err, reply) ->
					if !reply
						socket.in(room).emit('chat:' + room, serverSentMessage({
							class: "identity err",
							body: "There's no registration on file for " + nick
						}, room))
					else
						async.parallel {
							salt: (callback) ->
								redisC.hget("salts:" + room, nick, callback)
							password: (callback) ->
								redisC.hget("passwords:" + room, nick, callback)
						}, (err, stored) ->
							throw err if err
							crypto.pbkdf2 data.password, stored.salt, 4096, 256, (err, derivedKey) ->
								throw err if err

								# TODO: does not output the right nick while encrypted, may not be necessary as this functionality might change (re: GPG/PGP)
								if (derivedKey.toString() != stored.password) # FAIL
									client.set("identified", false)
									socket.in(room).emit('chat:' + room, serverSentMessage({
										class: "identity err",
										body: "Wrong password for " + nick
									}, room))
									socket.in(room).broadcast.emit('chat:' + room, serverSentMessage({
										class: "identity err",
										body: nick + " just failed to identify himself"
									}, room))

								else # ident'd
									client.set("identified", true)
									socket.in(room).emit('chat:' + room, serverSentMessage({
										class: "identity ack",
										body: "You are now identified for " + nick
									}, room))
			catch e # identification error
				socket.in(room).emit('chat:' + room, serverSentMessage({
					body: "Error identifying yourself: " + e
				}, room))

		"register_nick": (namespace, socket, channel, client, data) ->
			room = channel.get("name")
			nick = client.get("nick")
			redisC.sismember "users:#{room}", nick, (err, reply) ->
				throw err if err
				if !reply # nick is not in use
					try # try crypto & persistence
						crypto.randomBytes 256, (ex, buf) ->
							throw ex if ex
							salt = buf.toString()
							crypto.pbkdf2 data.password, salt, 4096, 256, (err, derivedKey) ->
								throw err if err

								redisC.sadd "users:#{room}", nick, (err, reply) ->
									throw err if err
								redisC.hset "salts:#{room}", nick, salt, (err, reply) ->
									throw err if err
								redisC.hset "passwords:#{room}", nick, derivedKey.toString(), (err, reply) ->
									throw err if err

								client.set("identified", true)
								socket.in(room).emit('chat:' + room, serverSentMessage({
									body: "You have registered your nickname.  Please remember your password."
								}, room))
					catch e
						socket.in(room).emit('chat:' + room, serverSentMessage({
							body: "Error in registering your nickname: " + e
						}, room))
				else # nick is already in use
					socket.in(room).emit('chat:' + room, serverSentMessage({
						body: "That nickname is already registered by somebody."
					}, room))

		"in_call": (namespace, socket, channel, client) ->
			client.set("inCall", true)

		"left_call": (namespace, socket, channel, client) ->
			client.set("inCall", false)

		"unsubscribe": (namespace, socket, channel, client) ->
			channel.clients.remove(client)

		unauthenticatedEvents: ["join_private"]


