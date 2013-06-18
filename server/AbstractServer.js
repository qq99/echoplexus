function AbstractServer (sio, redisC, EventBus, auth, Channels, ChannelModel) {

	var _ = require('underscore'),
		config = require('./config.js').Configuration,
		Client = require('../client/client.js').ClientModel,
		Clients = require('../client/client.js').ClientsCollection,
		Channel = ChannelModel,
		DEBUG = config.DEBUG;

	function Server () {
		this.initialized = false;

		this.name = "Default";
		this.SERVER_NAMESPACE = "/default"; // override in initialize

		// a list of events to bind to the client socket:
		this.events = [];
		// everything is assumed to be an authenticated route unless specified elsewise
		this.unauthenticatedEvents = [];
	};

	/*
		Initialize a server with a set of events.
		Provide any server-level overrides in here, e.g.,
		
		options: {
			SERVER_NAMESPACE: "/chat",
			events: [
				"chat": function (socket, channel, client, data) {
					this.emit("yo", {'some':'data'});
					// the context of "this" will be the server
				} 
			], // list of all events the server will be listening for
			unauthenticatedEvents: ["join_private"] // all other events will need to be authenticated
		}
	*/
	Server.prototype.initialize = function (options) {
		_.extend(this, options);

		this.initialized = true;
	};

	// TODO: find a nice way to move this into CodeServer.js
	function CodeCache (namespace) {
		var currentState = "",
			namespace = (typeof namespace !== "undefined") ? namespace : "",
			mruClient,
			ops = [];

		return {
			set: function (state) {
				currentState = state;
				ops = [];
			},
			add: function (op, client) {
				mruClient = client;
				ops.push(op);
			},
			syncFromClient: function () {
				if (typeof mruClient === "undefined") return;

				mruClient.socketRef.emit('code:request:' + namespace);
			},
			syncToClient: function () {
				return {
					start: currentState,
					ops: ops
				};
			},
			remove: function (client) {
				if (mruClient === client) {
					mruClient = null;
				}
			}
		};
	}

	Server.prototype.initializeClientEvents = function (socket, channel, client) {
		var server = this;

		// bind the events:
		_.each(this.events, function (method, eventName) {
			// DEBUG && console.log("binding", eventName + ":" + channel.get("namespace"));
			// wrap the event in an authentication filter:
			var authFiltered = _.wrap(method, function (meth) {
				var method_args = arguments;

				// get the socket's authentication status for the current channel.name
				// socket.get("authStatus", function (err, authStatus) {
					// don't do anything if the user is not authenticated for the channel
					// AND the event in question is an authenticated one
					// console.log(server.name, client.get("authenticated"));
					if ((client.get("authenticated") === false) && 
						!_.contains(server.unauthenticatedEvents, eventName)) {
						return;
					}
					// if (!authStatus[channel.name] &&
					// 	!_.contains(server.unauthenticatedEvents, eventName)) {
					// 	return;
					// }
					method_args = Array.prototype.slice.call(method_args).splice(1); // first argument is the function itself
					method_args.unshift(socket, channel, client);
					meth.apply(server, method_args); // not even once.
				// });
			});

			// bind the pre-filtered event
			socket.on(eventName + ":" + channel.get("namespace"), authFiltered);
		});
	};

	Server.prototype.start = function (callback) {
		var server = this;

		if (!this.initialized) {
			throw new Error("Server not yet initialized");
		}

		this.serverInstance = sio.of(this.SERVER_NAMESPACE).on('connection', function (socket) {

			socket.on("subscribe", function (data, subscribeAck) {
				var channelName = data.room,
					channelNamespace = data.subchannel,
					channelProperties,
					client,
					channel;

				// attempt to get the channel
				channel = Channels.findWhere({name: channelName});

				// create the channel if it doesn't already exist
				if (typeof channel === "undefined" ||
					channel === null) {
					// construct properties hash for the channel model
					if (channelNamespace) {
						channelProperties = {
							name: channelName,
							namespace: channelNamespace
						};
					} else {
						channelProperties = {
							name: channelName
						};
					}

					// create the channel
					channel = new Channel({
						name: channelName,
						namespace: channelNamespace
					});
					Channels.add(channel);
				}

				client = channel.clients.findWhere({sid: socket.id});
				console.log(server.name, "c", typeof client);

				if (typeof client === "undefined" ||
					client === null) { // there was no pre-existing client

					client = new Client({
						room: channelName,
						sid: socket.id
					});
					
					channel.clients.add(client);
				} else { // there was a pre-existing client
					if (client.get("authenticated")) {
						socket.join(channel.get("namespace"));
					}
				}

				// socket.join(channel.get("namespace"));
				client.socketRef = socket;

				client.on("change:authenticated", function (result) {
					console.log("change:authenticated", server.name, client.cid, socket.id, result.attributes.authenticated);
					if (result.attributes.authenticated) {
						socket.join(channel.get("namespace"));
						callback.success(socket, channel, client);
					} else {
						socket.leave(channel.get("namespace"));
					}
				})

				// attempt to authenticate on the chanenl
				channel.authenticate(client, "", function (err, response) {

					server.initializeClientEvents(socket, channel, client);

					if (subscribeAck !== null &&
						typeof (subscribeAck) !== "undefined") {
						subscribeAck({
							cid: client.cid
						});
					}

					// let any implementing servers handle errors the way they like
					if (err) {
						callback.error(err, socket, channel, client);
					}
					
				});

				// every server shall support a disconnect handler
				socket.on('disconnect', function () {
					if (typeof client !== "undefined") {
						DEBUG && console.log("Killing (d/c) ", client.cid, " from ", channelName);
						channel.clients.remove(client);
					}
				
					_.each(server.events, function (value, key) {
						socket.removeAllListeners(key + ":" + channelName);
					});
				});

				// every server shall support a unsubscribe handler (user closes channel but remains in chat)
				socket.on('unsubscribe', function () {
					if (typeof client !== "undefined") {
						DEBUG && console.log("Killing (left) ", client.cid, " from ", channelName);
						channel.clients.remove(client);
					}
				
					_.each(server.events, function (value, key) {
						socket.removeAllListeners(key + ":" + channelName);
					});
				});

			});

		});
	};

	return new Server();

}

exports.AbstractServer = AbstractServer;