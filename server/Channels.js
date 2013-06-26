exports.ChannelStructures = function (redisC, EventBus) {
	
	var Backbone = require('backbone'),
		_ = require('underscore'),
		async = require('async'),
		crypto = require('crypto'),
		ApplicationError = require('./Error'),
		Client = require('../client/client.js').ClientModel,
		Clients = require('../client/client.js').ClientsCollection,
		config = require('./config.js').Configuration,
		DEBUG = config.DEBUG;



	var ChannelModel = Backbone.Model.extend({
		isPrivate: function (callback) {
			return this.get("private");
		}
	});

	var ServerChannelModel = ChannelModel.extend({
		defaults: {
			name: ""
		},
		initialize: function (properties, options) {
			_.bindAll(this);
			// _.extend(this, options); // overwrite any collection methods
			
			this.clients = new Clients();
			this.replay = [];

			this.codeCaches = {};
		},
		isPrivate: function (callback) {
			var self = this,
				channelName = this.get("name");
			// if we've cached the redis result, return that
			if (false) {
				callback(null, this.get("private"));
			} else { // otherwise we don't know the state of isPrivate, so we query the db
				// only query the isPrivate once per lifetime
				redisC.hget("channels:" + channelName, "isPrivate", function (err, reply) {
					if (err) callback(err); // redis error
					if (reply === "true") { // channel is private
						DEBUG && console.log("user attempted to join private room", channelName);
						self.set("private", true);
						callback(null, true);
					} else { // channel is public
						DEBUG && console.log("user attempted to join public room", channelName);
						self.set("private", false);
						callback(null, false);
					}
				});
			}
		},
		makePrivate: function (channelPassword, callback) {
			// Attempts to make a channel private
			// Throws user friendly errors if:
			// - it's already private
			// - the new channel password is the empty string
			// - crypto or persistence fails
			var self = this,
				channelName = this.attributes.name;

			if (channelPassword === "") {
				callback(new Error("You must supply a password to make the channel private."));
			}

			this.isPrivate(function (err, privateChannel) {
				if (err) callback(err);
				
				if (privateChannel) {
					callback(new Error(channelName + " is already private"));
				} else {

					// attempt to make the channel private with the supplied password
					try { 
						// generate 256 random bytes to salt the password
						crypto.randomBytes(256, function (err, buf) {
							if (err) throw err; // crypto failed
							var salt = buf.toString();
							
							// run 4096 iterations producing a 256 byte key
							crypto.pbkdf2(channelPassword, salt, 4096, 256, function (err, derivedKey) {
								if (err) throw err; // crypto failed

								async.parallel([
									function (callback) {
										redisC.hset("channels:" + channelName, "isPrivate", true, callback);
									}, function (callback) {
										redisC.hset("channels:" + channelName, "salt", salt, callback);
									}, function (callback) {
										redisC.hset("channels:" + channelName, "password", derivedKey.toString(), callback);
									}
								], function (err, reply) {
									if (err) throw err;

									self.set("private", true);
									callback(null, true); // everything worked and the room is now private
								});

							});
						});
					} catch (e) { // catch any crypto or persistence error, and return a general error string
						callback(new Error("An error occured while attempting to make the channel private."));
					}

				}
			});
		},
		makePublic: function (callback) {
			// Attempts to make a channel public
			// Throws user friendly errors if:
			// - it's already public
			// - persistence fails
			var self = this,
				channelName = this.attributes.name;

			this.isPrivate(function (err, privateChannel) {
				if (err) callback(err);

				if (!privateChannel) {
					callback(new Error(channelName + " is already public"));
				}

				async.parallel([
					function (callback) {
						redisC.hdel("channels:" + channelName, "isPrivate", callback);
					}, function (callback) {
						redisC.hdel("channels:" + channelName, "salt", callback);
					}, function (callback) {
						redisC.hdel("channels:" + channelName, "password", callback);
					}
				], function (err, reply) {
					if (err) callback(new Error("An error occured while attempting to make the channel public."));

					self.set("private", false);
					callback(null, true); // everything worked and the room is now private
				});

			});
		},
		isSocketAlreadyAuthorized: function (socket) {
			var channelName = this.attributes.name;

			if (typeof socket.authStatus !== "undefined") {
				return socket.authStatus[channelName];
			}
		},
		getSocketAuthObject: function (socket, callback) {
			socket.get("authStatus", function (err, authObject) {
				if (err) callback(err);

				if (authObject === null) {
					authObject = {};
				}

				callback(null, authObject);
			});
		},
		authenticationSuccess: function (client) {
			var self = this,
				channelName = this.attributes.name,
				socket = client.socketRef;

			this.getSocketAuthObject(socket, function (err, authStatus) {
				if (err) throw err;

				authStatus[channelName] = true;
				socket.set("authStatus", authStatus, function () {
					DEBUG && console.log("authSucc", channelName, socket.id);

					client.set("authenticated", true);
					client.trigger("change:authenticated",client);
					// console.log(client.get("authenticated"));
					// socket.join(channelName);
					// EventBus.trigger("authentication:success", {
					// 	socket: socket,
					// 	channelName: channelName
					// });
				});
			});
		},
		authenticate: function (client, channelPassword, callback) {
			var self = this,
				socket = client.socketRef,
				channelName = this.attributes.name;

			// preempt any expensive checks
			if (this.isSocketAlreadyAuthorized(socket, channelName)) {
				callback(null, true);
			}

			this.isPrivate(function (err, privateChannel) {
				if (err) callback(new Error("An error occured while attempting to join the channel."));

				if (privateChannel) {

					// get the salt and salted+hashed password
					async.parallel({
						salt: function (callback) {
							redisC.hget("channels:" + channelName, "salt", callback);
						},
						password: function (callback) {
							redisC.hget("channels:" + channelName, "password", callback);
						}
					}, function (err, stored) {
						if (err) callback(err);
	
						crypto.pbkdf2(channelPassword, stored.salt, 4096, 256, function (err, derivedKey) {
							if (err) callback(err);

							if (derivedKey.toString() !== stored.password) { // auth failure
								callback(new ApplicationError.Authentication("Incorrect password."));
							} else { // auth success
								self.authenticationSuccess(client);
								callback(null, true);
							}
						});
					});
				} else {
					self.authenticationSuccess(client);
					callback(null, true);
				}
			});
		}
	});

	var ChannelsCollection = Backbone.Collection.extend({
		initialize: function (instances, options) {
			_.bindAll(this);
			_.extend(this, options);
		},
		listPublicActive: function () {

		}
	});

	return {
		ChannelsCollection: ChannelsCollection,
		ServerChannelModel: ServerChannelModel
	};

};