exports.ClientStructures = function (redisC, EventBus) {
	var _ = require('underscore'),
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
				self.loadMetadata();
				self.getPermissions();
			});

			Client.prototype.initialize.apply(this, arguments);

			// rate limit the client's chat, if it's enabled
			if (config &&
				config.chat &&
				config.chat.rate_limiting &&
				config.chat.rate_limiting.enabled) {

				this.tokenBucket = new TokenBucket();
			}

		},
		getPermissions: function () {

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