function AbstractServer (sio, redisC, EventBus, auth) {

	var _ = require('underscore'),
		config = require('./config.js').Configuration,
		Client = require('../client/client.js').ClientModel,
		Clients = require('../client/client.js').ClientsCollection,
		DEBUG = config.DEBUG;

	function Channel (options) {
		this.name = options.name;

		if (options.namespace) { // e.g., "code:js" and "code:html"
			this.namespace = options.namespace;
		} else { // e.g., chat, which doesn't have subchannels
			this.namespace = this.name;
		}

		this.clients = new Clients();
		return this;
	}

	function Server () {
		this.initialized = false;

		this.SERVER_NAMESPACE = "/default"; // override in initialize
		this.channels = {}; // the server's list of active channels

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

	Server.prototype.initializeClientEvents = function (socket, channel, client) {
		var server = this;

		// bind the events:
		_.each(this.events, function (method, eventName) {

			// wrap the event in an authentication filter:
			var authFiltered = _.wrap(method, function (meth) {
				var method_args = arguments;

				// get the socket's authentication status for the current channel.name
				socket.get("authStatus", function (err, authStatus) {

					// don't do anything if the user is not authenticated for the channel
					// AND the event in question is an authenticated one
					if (!authStatus[channel.name] &&
						!_.contains(server.unauthenticatedEvents, eventName)) {
						return;
					}
					method_args = Array.prototype.slice.call(method_args).splice(1); // first argument is the function itself
					method_args.unshift(socket, channel, client);
					meth.apply(server, method_args); // not even once.
				});
			});

			// bind the pre-filtered event
			socket.on(eventName + ":" + channel.namespace, authFiltered);
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
					client,
					channelNamespace,
					channel = server.channels[channelName];

				// create the channel if it doesn't already exist
				if (typeof channel === "undefined") {
					channel = new Channel({
						name: channelName
					});
					server.channels[channelName] = channel;
				}

				auth.authenticate(socket, channelName, "", function (err, response) {		
					client = new Client({
						room: channelName
					});
					client.socketRef = socket;

					server.initializeClientEvents(socket, channel, client);

					subscribeAck({
						cid: client.cid
					});

					if (callback) {
						callback(err, socket, channel, client);
					}
				});

				socket.on('disconnect', function () {
					if (typeof client !== "undefined") { // sometimes client is undefined; TODO: find out why
						DEBUG && console.log("Killing ", client.cid, " from ", channelName);
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