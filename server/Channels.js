exports.ChannelStructures = function (redisC, EventBus) {
	
	var Backbone = require('backbone'),
		_ = require('underscore'),
		async = require('async'),
		crypto = require('crypto'),
		ApplicationError = require('./Error'),
		ClientStructures = require('./client.js').ClientStructures(redisC, EventBus),
		Client = ClientStructures.ServerClient,
		Clients = require('../client/client.js').ClientsCollection,
		config = require('./config.js').Configuration,
		PermissionModel = require('./PermissionModel').ChannelPermissionModel,
		DEBUG = config.DEBUG;

	var ChannelModel = Backbone.Model.extend({
		isPrivate: function (callback) {
			return this.get("private");
		}
	});

	var ServerChannelModel = ChannelModel.extend({
		defaults: {
			name: "",
			private: null,
			hasOwner: null // no one can become an owner until the status of this is resolved
		},
		initialize: function (properties, options) {
			_.bindAll(this);

			this.initialized = false;
			
			this.clients = new Clients();
			this.replay = [];
			this.call = {};

			this.codeCaches = {};

			this.getOwner();

			this.permissions = new PermissionModel();

			this.getPermissions();
		},
		hasPermission: function (client, permName) {
			var perm;

			// first check user perms
			perm = client.hasPermission(permName);
			if (perm === null) {
				// if not set, check channel perms
				perm = this.permissions.get(permName);
				if (perm === null) perm = false; // if not set, default is deny
			}

			return perm;
		},
		getPermissions: function () {
			var self = this,
				room = this.get("name");

			redisC.hget("permissions:" + room, "channel_perms", function (err, reply) {
				if (err) throw err;

				if (reply) {
					var stored_permissions = JSON.parse(reply);
					self.permissions.set(stored_permissions);
				}
			});
		},
		persistPermissions: function () {
			var room = this.get("name");

			redisC.hset("permissions:" + room, "channel_perms", JSON.stringify(this.permissions.toJSON()));
		},
		getOwner: function () {
			var self = this,
				channelName = this.get("name");

			// only query the hasOwner once per lifetime
			redisC.hget("channels:" + channelName, "owner_derivedKey", function (err, reply) {
				if (reply) { // channel has an owner
					self.set("hasOwner", true);
				} else { // no owner
					self.set("hasOwner", false);
				}
			});
		},
		assumeOwnership: function (client, key, callback) {
			var self = this,
				channelName = this.get("name");

			if (this.get("hasOwner") === false) {
				this.setOwner(key, function (err, result) {
					if (err) throw err;

					callback(null, result);
				});
			} else if (this.get("hasOwner") === true) {
				// get the salt and salted+hashed password
				async.parallel({
					salt: function (callback) {
						redisC.hget("channels:" + channelName, "owner_salt", callback);
					},
					password: function (callback) {
						redisC.hget("channels:" + channelName, "owner_derivedKey", callback);
					}
				}, function (err, stored) {
					if (err) callback(err);

					crypto.pbkdf2(key, stored.salt, 4096, 256, function (err, derivedKey) {
						if (err) callback(err);

						if (derivedKey.toString() !== stored.password) { // auth failure
							callback(new ApplicationError.Authentication("Incorrect password."));
						} else { // auth success
							callback(null, "You have proven that you are the channel owner.");
						}
					});
				});
			}
		},
		setOwner: function (key, callback) {
			var self = this,
				channelName = this.get("name");

			// attempt to make the channel private with the supplied password
			try {
				// generate 256 random bytes to salt the password
				crypto.randomBytes(256, function (err, buf) {
					if (err) throw err; // crypto failed
					var salt = buf.toString();

					// run 4096 iterations producing a 256 byte key
					crypto.pbkdf2(key, salt, 4096, 256, function (err, derivedKey) {
						if (err) throw err; // crypto failed

						async.parallel([
							function (callback) {
								redisC.hset("channels:" + channelName, "owner_salt", salt, callback);
							}, function (callback) {
								redisC.hset("channels:" + channelName, "owner_derivedKey", derivedKey.toString(), callback);
							}
						], function (err, reply) {
							if (err) throw err;

							self.set("hasOwner", true);
							callback(null, "You are now the channel owner."); // everything worked and the room is now private
						});

					});
				});
			} catch (e) { // catch any crypto or persistence error, and return a general error string
				callback(new Error("An error occured while attempting to set a channel owner."));
			}
		},
		isPrivate: function (callback) {
			var self = this,
				channelName = this.get("name");
			// if we've cached the redis result, return that
			if (this.get("private") !== null) {
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
					client.trigger("authenticated",client);
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

			var self = this;

			// since we're also the authentication provider, we must
			// respond to any requests that wish to know if our client (HTTP/XHR)
			// has successfully authenticated
			EventBus.on("has_permission", function (clientQuery, callback) {
				// find the room he's purportedly in
				var inChannel = self.findWhere({name: clientQuery.channel});
				if (typeof inChannel === "undefined" ||
					inChannel === null) {

					callback(403, "That channel does not exist.");
					return;
				}
				// find the client matching the ID he purports to be
				var fromClient = inChannel.clients.findWhere({id: clientQuery.from_user});
				if (typeof fromClient === "undefined" ||
					fromClient === null) {

					callback(403, "You are not a member of that channel.");
					return;
				}
				// find whether his antiforgery token matches
				if (fromClient.antiforgery_token !== clientQuery.antiforgery_token) {
					callback(403, "Please don't spoof requests.");
					return;
				}
				// find whether he's authenticated for the channel in question
				if (!fromClient.get("authenticated")) {
					callback(403, "You are not authenticated for that channel.");
					return;
				}

				// finally, find whether he has permission to perform the requested operation:
				if (!inChannel.hasPermission(fromClient, clientQuery.permission)) {
					callback(403, "You do not have permission to perform this operation.");
					return;
				}

				// he passed all auth checks:
				callback(null);
			});
		},
		listPublicActive: function () {

		}
	});

	return {
		ChannelsCollection: ChannelsCollection,
		ServerChannelModel: ServerChannelModel
	};

};