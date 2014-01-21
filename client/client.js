(function(root, factory) {
  // Set up Backbone appropriately for the environment.
  if (typeof exports !== 'undefined') {
    // Node/CommonJS, no need for jQuery in that case.
    factory(exports,require('backbone'),require('underscore'),require('../server/PermissionModel.js').ClientPermissionModel,require('../client/regex.js').REGEXES, null, require('../server/config.js').Configuration);
  } else if (typeof define === 'function' && define.amd) {
    // AMD
    define(['underscore', 'backbone', 'PermissionModel', 'regex', 'CryptoWrapper', 'exports'],
    	function(_, Backbone, PermissionModel, Regex, crypto, exports) {
      // Export global even in AMD case in case this script is loaded with
      // others that may still expect a global Backbone.
      return factory(exports, Backbone, _, PermissionModel.PermissionModel, Regex.REGEXES, crypto);
    });
  }
})(this,function(exports, Backbone, _, PermissionModel, REGEXES, crypto, config) {

	exports.ColorModel = Backbone.Model.extend({
		defaults: {
			r: 0,
			g: 0,
			b: 0
		},
		initialize: function (opts) {
			if (opts) {
				this.set("r", opts.r);
				this.set("g", opts.g);
				this.set("b", opts.b);
			} else {
				var r = parseInt(Math.random()*200+55,10), // push the baseline away from black
					g = parseInt(Math.random()*200+55,10),
					b = parseInt(Math.random()*200+55,10),
					threshold = 50, color = 35;
				//Calculate the manhattan distance to the colors
				//If the colors are within the threshold, invert them
				if (Math.abs(r - color) + Math.abs(g - color) + Math.abs(b - color) <= threshold)
				{
					r = 255 - r;
					g = 255 - g;
					b = 255 - b;
				}
				this.set("r", r);
				this.set("g", g);
				this.set("b", b);
			}
		},
		parse: function (userString, callback) {
			if (userString.match(REGEXES.colors.hex)) {
				this.setFromHex(userString);
				callback(null);
			} else { // only 6-digit hex is supported for now
				callback(new Error("Invalid colour; you must supply a valid CSS hex color code (e.g., '#efefef', '#fff')"));
				return;
			}
		},
		setFromHex: function (hexString) {
			// trim any leading "#"
			if (hexString.charAt(0) === "#") { // strip any leading # symbols
				hexString = hexString.substring(1);
			}
			if (hexString.length === 3) { // e.g. fff -> ffffff
				hexString += hexString;
			}

			var r, g, b;
			r = parseInt(hexString.substring(0,2), 16);
			g = parseInt(hexString.substring(2,4), 16);
			b = parseInt(hexString.substring(4,6), 16);

			this.set({
				r: r,
				g: g,
				b: b
			});
		},
		toRGB: function () {
			return "rgb(" + this.attributes.r + "," + this.attributes.g + "," + this.attributes.b + ")";
		}
	});

	exports.ClientsCollection = Backbone.Collection.extend({
		model: exports.ClientModel
	});

	exports.ClientModel = Backbone.Model.extend({
		supported_metadata: ["email", "website_url", "country_code", "gender"],
		defaults: {
			nick: "Anonymous",
			identified: false,
			idle: false,
			isServer: false,
			authenticated: false,

			email: null,
			country_code: null,
			gender: null,
			website_url: null,
		},
		toJSON: function() {
			var json = Backbone.Model.prototype.toJSON.apply(this, arguments);
  			json.cid = this.cid;
			return json;
		},
		initialize: function (opts) {
			_.bindAll(this);

			if (opts && opts.color) {
				this.set("color", new exports.ColorModel(opts.color));
			} else {
				this.set("color", new exports.ColorModel());
			}
			if (opts && opts.socket) {
				this.socket = opts.socket;
			}

			this.set("permissions", new PermissionModel());
		},
		channelAuth: function (pw, room) {
			$.cookie("channel_pw:" + room, pw, window.COOKIE_OPTIONS);

			this.socket.emit('join_private:' + room, {
				password: pw,
				room: room
			});
		},
		inactive: function (reason, room, socket) {
			reason = reason || "User idle.";

			socket.emit("chat:idle:" + room, {
				reason: reason,
				room: room
			});
			this.set('idle',true);
		},
		active: function (room, socket) {
			if (this.get('idle')) { // only send over wire if we're inactive
				socket.emit("chat:unidle:" + room);
				this.set('idle',false);
			}
		},
		getNick: function (cryptoKey) {
			var nick = this.get("nick"),
				encrypted_nick = this.get("encrypted_nick");

			if (typeof encrypted_nick !== "undefined") {

				if ((typeof cryptoKey !== "undefined") &&
					(cryptoKey !== "")) {

					nick = crypto.decryptObject(encrypted_nick, cryptoKey);
				} else {
					nick = encrypted_nick.ct;
				}
			}

			return nick;
		},
		setNick: function (nick, room, ack) {
			$.cookie("nickname:" + room, nick, window.COOKIE_OPTIONS);

			if (this.cryptokey) {
				this.set("encrypted_nick", crypto.encryptObject(nick, this.cryptokey), {silent: true});
				nick = "-";
			}

			this.socket.emit('nickname:' + room, {
				nick: nick,
				encrypted_nick: this.get("encrypted_nick")
			}, function () {
				if (ack) {
					ack.resolve();
				}
			});
		},
		identify: function (pw, room, ack) {
			$.cookie("ident_pw:" + room, pw, window.COOKIE_OPTIONS);
			this.socket.emit('identify:' + room, {
				password: pw,
				room: room
			}, function () {
				ack.resolve();
			});
		},
		is: function (otherModel) {
			return (this.attributes.id === otherModel.attributes.id);
		},
		speak: function (msg, socket) {
			var self = this,
				body = msg.body,
				room = msg.room,
				matches;
			window.events.trigger("speak",socket,this,msg);
			if (!body) return; // if there's no body, we probably don't want to do anything
			if (body.match(REGEXES.commands.nick)) { // /nick [nickname]
				body = body.replace(REGEXES.commands.nick, "").trim();
				this.setNick(body, room);
				$.cookie("nickname:" + room, body, window.COOKIE_OPTIONS);
				$.removeCookie("ident_pw:" + room, window.COOKIE_OPTIONS); // clear out the old saved nick
			} else if (body.match(REGEXES.commands.private)) {  // /private [password]
				body = body.replace(REGEXES.commands.private, "").trim();
				socket.emit('make_private:' + room, {
					password: body,
					room: room
				});
				$.cookie("channel_pw:" + room, body, window.COOKIE_OPTIONS);
			} else if (body.match(REGEXES.commands.public)) {  // /public
				body = body.replace(REGEXES.commands.public, "").trim();
				socket.emit('make_public:' + room, {
					room: room
				});
			} else if (body.match(REGEXES.commands.password)) {  // /password [password]
				body = body.replace(REGEXES.commands.password, "").trim();
				this.channelAuth(body, room);
			} else if (body.match(REGEXES.commands.register)) {  // /register [password]
				body = body.replace(REGEXES.commands.register, "").trim();
				socket.emit('register_nick:' + room, {
					password: body,
					room: room
				});
				$.cookie("ident_pw:" + room, body, window.COOKIE_OPTIONS);
			} else if (body.match(REGEXES.commands.identify)) { // /identify [password]
				body = body.replace(REGEXES.commands.identify, "").trim();
				this.identify(body, room);
			} else if (body.match(REGEXES.commands.topic)) { // /topic [My channel topic]
				body = body.replace(REGEXES.commands.topic, "").trim();


				if (this.cryptokey) {
					var encrypted_topic = crypto.encryptObject(body, this.cryptokey);
					body = "-";
					socket.emit('topic:' + room, {
						encrypted_topic: encrypted_topic,
						room: room
					});
				} else {
					socket.emit('topic:' + room, {
						topic: body,
						room: room
					});
				}

			} else if (body.match(REGEXES.commands.private_message)) { // /tell [nick] [message]
				body = body.replace(REGEXES.commands.private_message, "").trim();

				var targetNick = body.split(" "); // take the first token to mean the

				if (targetNick.length) { // only do something if they've specified a target
					targetNick = targetNick[0];

					if (targetNick.charAt(0) === "@") { // remove the leading "@" symbol while we match against it; TODO: validate username characters not to include special symbols
						targetNick = targetNick.substring(1);
					}

					/*
						check to see if we're in encrypted mode;
						if we are, then we probably don't care about pm'ing a non-encrypted
						user, and so we'll pm their ciphernick instead
					*/
					if (this.cryptokey) {
						// decrypt the list of our peers (we don't have their unencrypted stored in plaintext anywhere)
						var peerNicks = _.map(this.peers.models, function (peer) {
							return peer.getNick(self.cryptokey);
						}), ciphernicks = []; // we could potentially be targeting multiple people with the same nick in our whisper

						// check this decrypted list for the target nick
						for (var i = 0; i < peerNicks.length; i++) {
							// if it matches, we'll keep track of their ciphernick to send to the server
							if (peerNicks[i] === targetNick) {
								ciphernicks.push(this.peers.at(i).get("encrypted_nick")["ct"]);
							}
						}

						// if anyone was actually a recipient, we'll encrypt the message and send it
						if (ciphernicks.length) {

							// encrypt the body text
							var encrypted = crypto.encryptObject(body, this.cryptokey);
							body = "-"; // clean it immediately after encrypting it

							socket.emit('private_message:' + room, {
								encrypted: encrypted,
								ciphernicks: ciphernicks,
								body: body,
								room: room
							});
						} // else we just do nothing.
					} else { // it wasn't sent while encrypted, the simple case
						socket.emit('private_message:' + room, {
							body: body,
							room: room,
							directedAt: targetNick
						});
					}
				}
			} else if (body.match(REGEXES.commands.pull_logs)) { // pull
				body = body.replace(REGEXES.commands.pull_logs, "").trim();

				if (body === "ALL") {
					console.warn("/pull all -- Not implemented yet");
				} else {
					var nLogs = Math.max(1, parseInt(body, 10));
						nLogs = Math.min(100, nLogs), // 1 <= N <= 100
						missed = this.persistentLog.getMissingIDs(nLogs);

					if (missed.length) {
						this.socket.emit("chat:history_request:" + room, {
						 	requestRange: missed
						});
					}
				}
			} else if (body.match(REGEXES.commands.set_color)) { // pull
				body = body.replace(REGEXES.commands.set_color, "").trim();

				socket.emit('user:set_color:' + room, {
					userColorString: body
				});
			} else if (matches = body.match(REGEXES.commands.edit)) { // editing
				var mID = matches[2], data;

				body = body.replace(REGEXES.commands.edit, "").trim();

				data = {
					mID: mID,
					body: body,
				};

				if (this.cryptokey) {
					data.encrypted = crypto.encryptObject(data.body, this.cryptokey);
					data.body = "-";
				}

				socket.emit('chat:edit:' + room, data);
			} else if (body.match(REGEXES.commands.leave)) { // leaving
				window.events.trigger('leave:' + room);
			} else if (body.match(REGEXES.commands.chown)) { // become owner
				body = body.replace(REGEXES.commands.chown, "").trim();
				socket.emit('chown:' + room, {
					key: body
				});
			} else if (body.match(REGEXES.commands.chmod)) { // change permissions
				body = body.replace(REGEXES.commands.chmod, "").trim();
				socket.emit('chmod:' + room, {
					body: body
				});
			} else if (body.match(REGEXES.commands.broadcast)) { // broadcast to speak to all open channels at once
				body = body.replace(REGEXES.commands.broadcast, "").trim();
				window.events.trigger('chat:broadcast', {
					body: body
				});
			} else if (body.match(REGEXES.commands.help)) {
				socket.emit('help:' + room);
			} else if (body.match(REGEXES.commands.roll)) {
			        socket.emit('roll:' + room);
        			console.warn("/roll -- Not implemented yet");
			} else if (body.match(REGEXES.commands.failed_command)) { // match all
				// NOOP
			} else { // send it out to the world!

				if (this.cryptokey) {
					msg.encrypted = crypto.encryptObject(msg.body, this.cryptokey);
					msg.body = "-";
				}
				socket.emit('chat:' + room, msg);
			}
		}
	});

});
