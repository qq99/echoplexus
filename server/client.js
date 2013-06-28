exports.ClientStructures = function (redisC, EventBus) {
	var _ = require('underscore'),
		Client = require('../client/client.js').ClientModel;

	this.ServerClient = Client.extend({
		initialize: function () {
			var self = this;

			console.log("ServerClient initialize");

			this.on("change:identified", function (data) {
				self.loadMetadata();
			});

			Client.prototype.initialize.apply(this, arguments);
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