function AbstractServer (sio, redisC, EventBus, Channels, ChannelModel) {

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



	Server.prototype.initializeClientEvents = function (namespace, socket, channel, client) {
		var server = this;

		// bind the events:
		_.each(this.events, function (method, eventName) {
			// wrap the event in an authentication filter:
			var authFiltered = _.wrap(method, function (meth) {
				var method_args = arguments;

				if ((client.get("authenticated") === false) && 
					!_.contains(server.unauthenticatedEvents, eventName)) {
					return;
				}
				//DEBUG && console.log(eventName + ":" + namespace);
				method_args = Array.prototype.slice.call(method_args).splice(1); // first argument is the function itself
				method_args.unshift(namespace, socket, channel, client);
				meth.apply(server, method_args); // not even once.
			});

			// bind the pre-filtered event
			socket.on(eventName + ":" + namespace, authFiltered);
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
					subchannel = data.subchannel,
					namespace,
					channelProperties,
					client,
					channel;
				if (typeof subchannel !== "undefined") {
					namespace = channelName + ":" + subchannel;
				} else {
					namespace = channelName;
				}

				// attempt to get the channel
				channel = Channels.findWhere({name: channelName});

				// create the channel if it doesn't already exist
				if (typeof channel === "undefined" ||
					channel === null) {

					// create the channel
					channel = new Channel({
						name: channelName
					});
					Channels.add(channel);
				}

				client = channel.clients.findWhere({sid: socket.id});
				// console.log(server.name, "c", typeof client);

				if (typeof client === "undefined" ||
					client === null) { // there was no pre-existing client

					client = new Client({
						room: channelName,
						sid: socket.id
					});
					client.socketRef = socket;					
					channel.clients.add(client);
				} else { // there was a pre-existing client
					if (client.get("authenticated")) {
						socket.join(namespace);
					}
				}



				client.once("authenticated", function (result) {
					DEBUG && console.log("authenticated", server.name, client.cid, socket.id, result.attributes.authenticated);
					if (result.attributes.authenticated) {
						socket.join(namespace);
						callback.success(namespace, socket, channel, client);

						if (subscribeAck !== null &&
							typeof (subscribeAck) !== "undefined") {
							subscribeAck({
								cid: client.cid
							});
						}
					} else {
						socket.leave(namespace);
					}
				});
				// attempt to authenticate on the chanenl
				channel.authenticate(client, "", function (err, response) {
					server.initializeClientEvents(namespace, socket, channel, client);

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
				socket.on('unsubscribe:' + namespace, function () {
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