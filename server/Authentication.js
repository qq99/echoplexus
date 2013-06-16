exports.AuthenticationModule = function (redisC, EventBus) {

	var async = require('async'),
		crypto = require('crypto'),
		ApplicationError = require('./Error');

	// check to see if the room is private:
	function isPrivate (channelName, callback) {
		redisC.hget("channels:" + channelName, "isPrivate", function (err, reply) {
			if (err) callback(err); // redis error
			if (reply === "true") { // channel is private
				DEBUG && console.log("user attempted to join private room", channelName);
				callback(null, true);
			} else { // channel is public
				DEBUG && console.log("user attempted to join public room", channelName);
				callback(null, false);
			}
		});
	}

	// Attempts to make a channel private
	// Throws user friendly errors if:
	// - it's already private
	// - the new channel password is the empty string
	// - crypto or persistence fails
	function makePrivate (channelName, channelPassword, callback) {
		if (channelPassword === "") {
			callback(new Error("You must supply a password to make the channel private."));
		}

		isPrivate(channelName, function (err, privateChannel) {
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
								callback(null, true); // everything worked and the room is now private
							});

						});
					});
				} catch (e) { // catch any crypto or persistence error, and return a general error string
					callback(new Error("An error occured while attempting to make the channel private."));
				}

			}
		});
	}


	// Attempts to make a channel public
	// Throws user friendly errors if:
	// - it's already public
	// - persistence fails
	function makePublic (channelName, callback) {

		isPrivate(channelName, function (err, privateChannel) {
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
				callback(null, true); // everything worked and the room is now private
			});

		});
	}

	function alreadyAuthorized (socket, channelName) {
		if (typeof socket.authStatus !== "undefined") {
			return socket.authStatus[channelName];
		}
	}

	function getAuthObject(socket, callback) {
		socket.get("authStatus", function (err, authObject) {
			if (err) callback(err);

			if (authObject === null) {
				authObject = {};
			}

			callback(null, authObject);
		});
	}

	// performs side effects on the socket itself
	function authSuccess (socket, channelName) {

		getAuthObject(socket, function (err, authStatus) {
			if (err) throw err;

			authStatus[channelName] = true;
			socket.set("authStatus", authStatus, function () {
				console.log("authSucc", channelName, socket.id);

				socket.join(channelName);
				EventBus.trigger("authentication:success", {
					socket: socket,
					channelName: channelName
				});
			});
		});

	}

	// stores data & triggers events on the socket itself when attempting to join
	function authenticate (socket, channelName, channelPassword, callback) {

		// preempt any expensive checks
		if (alreadyAuthorized(socket, channelName)) {
			callback(null, true);
		}

		isPrivate(channelName, function (err, privateChannel) {
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
							authSuccess(socket, channelName);
							callback(null, true);
						}
					});
				});
			} else {
				authSuccess(socket, channelName);
				callback(null, true);
			}
		});
	}

	function unauthenticate (socket, channelName) {
		if (typeof socket.authStatus !== "undefined") {
			delete socket.authStatus[channelName];
		}
		socket.leave(channelName);
	}

	return {
		authenticate: authenticate,
		unauthenticate: unauthenticate,
		makePublic: makePublic,
		makePrivate: makePrivate
	};
};