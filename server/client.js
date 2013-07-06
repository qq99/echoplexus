exports.ClientStructures = function (redisC, EventBus) {
	var _ = require('underscore'),
		uuid = require('node-uuid'),
		config = require('../server/config.js').Configuration,
		Client = require('../client/client.js').ClientModel;

	function TokenBucket () {
		// from: http://stackoverflow.com/questions/667508/whats-a-good-rate-limiting-algorithm

		var rate = config.chat.rate_limiting.rate, // unit: # messages
			per  = config.chat.rate_limiting.per, // unit: milliseconds
			allowance = rate, // unit: # messages
			last_check = Number(new Date()); // unit: milliseconds

		this.rateLimit = function () {
			var current = Number(new Date()),
				time_passed = current - last_check;

			last_check = current;
			allowance += time_passed * (rate / per);

			if (allowance > rate) {
				allowance = rate; // throttle
			}

			if (allowance < 1.0) {
				return true; // discard message, "true" to rate limiting
			} else {
				allowance -= 1.0;
				return false; // allow message, "false" to rate limiting
			}
		};
	}

	this.ServerClient = Client.extend({
		initialize: function () {
			var self = this;

			console.log("ServerClient initialize");

			this.on("change:identified", function (data) {
				console.log("changed:identified");
				self.loadMetadata();
				self.setIdentityToken(function (err) {
					if (err) throw err;
					self.getPermissions();
				});
			});

			Client.prototype.initialize.apply(this, arguments);

			// set a good global identifier
			if (typeof uuid !== "undefined") {
				this.set("id", uuid.v4());
			}

			// rate limit the client's chat, if it's enabled
			if (config &&
				config.chat &&
				config.chat.rate_limiting &&
				config.chat.rate_limiting.enabled) {

				this.tokenBucket = new TokenBucket();
			}

		},
		setIdentityToken: function (callback) {
			var token,
				room = this.get("room"),
				nick = this.get("nick");

			// check to see if a token already exists for the user
			redisC.hget("identity_token:" + room, nick, function (err, reply) {
				if (err) callback(err);

				if (!reply) { // if not, make a new one
					token = uuid.v4();
					redisC.hset("identity_token:" + room, nick, token, function (err, reply) { // persist it
						if (err) throw err;
						this.identity_token = token; // store it on the client object
						callback(null);
					});
				} else {
					token = reply;
					this.identity_token = token; // store it on the client object
					callback(null);
				}
			});
		},
		hasPermission: function (permName) {
			return this.get("permissions").get(permName);
		},
		becomeChannelOwner: function () {
			this.get("permissions").upgradeToOperator();
			this.set("operator", true); // TODO: add a way to send client data on change events
		},
		getPermissions: function () {
			var room = this.get("room"),
				nick = this.get("nick"),
				identity_token = this.identity_token;

			console.log("getting permissions");

			redisC.hget("permissions:" + room, nick + ":" + identity_token, function (err, reply) {
				if (err) throw err;

				console.log("permissions were",reply);
				if (reply) {
					var stored_permissions = JSON.parse(reply);

					this.get("permissions").set(stored_permissions);
				}
			});
		},
		metadataToArray: function () {
			var self = this,
				data = [];

			_.each(this.supported_metadata, function (field) {
				data.push(field);
				data.push(self.get(field));
			});

			return data;
		},
		saveMetadata: function (callback) {
			if (this.get("identified")) {
				var room = this.get("room"),
					nick = this.get("nick"),
					data = this.metadataToArray();

				redisC.hmset("users:room:" + nick, data, function (err, reply) {
					if (err) throw err;
					callback(null);
				});
			}
		},
		loadMetadata: function () {
			var self = this;

			if (this.get("identified")) {
				var room = this.get("room"),
					nick = this.get("nick"),
					fields = {};

				redisC.hmget("users:room:" + nick, this.supported_metadata, function (err, reply) {
					if (err) throw err;

					console.log("metadata:", reply);

					for (var i = 0; i < reply.length; i++) {
						fields[self.supported_metadata[i]] = reply[i];
					}
					console.log(fields);
					self.set(fields, {trigger: true});

					return reply; // just in case
				});
			}
		}
	});

	return this;
};