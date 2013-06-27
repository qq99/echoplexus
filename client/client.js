(function(root, factory) {
  // Set up Backbone appropriately for the environment.
  if (typeof exports !== 'undefined') {
    // Node/CommonJS, no need for jQuery in that case.
    factory(exports,require('backbone'),require('underscore'),require('../client/regex.js').REGEXES, require('node-uuid'), require('../server/config.js').Configuration);
  } else if (typeof define === 'function' && define.amd) {
    // AMD
    define(['underscore', 'backbone', 'regex', 'exports'], function(_, Backbone,Regex,exports) {
      // Export global even in AMD case in case this script is loaded with
      // others that may still expect a global Backbone.
      return factory(exports, Backbone, _,Regex.REGEXES);
    });
  }
})(this,function(exports,Backbone,_,REGEXES, uuid, config) {

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

	exports.ClientModel = Backbone.Model.extend({
		defaults: {
			nick: "Anonymous",
			identified: false,
			idle: false,
			isServer: false,
			authenticated: false
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
				DEBUG && console.log("sending active msg");
				socket.emit("chat:unidle:" + room);
				this.set('idle',false);
			}
		},
		setNick: function (nick, room, ack) {
			$.cookie("nickname:" + room, nick, window.COOKIE_OPTIONS);

			this.set("nick", nick);
			this.socket.emit('nickname:' + room, {
				nickname: nick
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
		is: function (cid) {
			return (this.cid === cid);
		},
		speak: function (msg, socket) {
			var body = msg.body,
				room = msg.room,
				matches;
			window.events.trigger("speak",socket,this,msg);
			if (!body) return; // if there's no body, we probably don't want to do anything
			if (body.match(REGEXES.commands.nick)) { // /nick [nickname]
				body = body.replace(REGEXES.commands.nick, "").trim();
				this.setNick(body, room);
				$.cookie("nickname:" + room, body, window.COOKIE_OPTIONS);
				$.removeCookie("ident_pw:" + room, window.COOKIE_OPTIONS); // clear out the old saved nick
				return;
			} else if (body.match(REGEXES.commands.private)) {  // /private [password]
				body = body.replace(REGEXES.commands.private, "").trim();
				socket.emit('make_private:' + room, {
					password: body,
					room: room
				});
				$.cookie("channel_pw:" + room, body, window.COOKIE_OPTIONS);
				return;
			} else if (body.match(REGEXES.commands.public)) {  // /public
				body = body.replace(REGEXES.commands.public, "").trim();
				socket.emit('make_public:' + room, {
					room: room
				});
				return;
			} else if (body.match(REGEXES.commands.password)) {  // /password [password]
				body = body.replace(REGEXES.commands.password, "").trim();
				this.channelAuth(body, room);
				return;
			} else if (body.match(REGEXES.commands.register)) {  // /register [password]
				body = body.replace(REGEXES.commands.register, "").trim();
				socket.emit('register_nick:' + room, {
					password: body,
					room: room
				});
				$.cookie("ident_pw:" + room, body, window.COOKIE_OPTIONS);
				return;
			} else if (body.match(REGEXES.commands.identify)) { // /identify [password]
				body = body.replace(REGEXES.commands.identify, "").trim();
				this.identify(body, room);
				return;
			} else if (body.match(REGEXES.commands.topic)) { // /topic [My channel topic]
				body = body.replace(REGEXES.commands.topic, "").trim();
				socket.emit('topic:' + room, {
					topic: body,
					room: room
				});
				return;
			} else if (body.match(REGEXES.commands.private_message)) { // /tell [nick] [message]
				body = body.replace(REGEXES.commands.private_message, "").trim();

				var targetNick = body.split(" "); // take the first token to mean the

				if (targetNick.length) {
					targetNick = targetNick[0];
					body = body.replace(targetNick, "").trim();
					if (targetNick.charAt(0) === "@") { // remove the leading "@" symbol; TODO: validate username characters not to include special symbols
						targetNick = targetNick.substring(1);
					}

					socket.emit('private_message:' + room, {
						body: body,
						room: room,
						directedAt: targetNick
					});
				}
				return;
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
				return;
			} else if (body.match(REGEXES.commands.set_color)) { // pull
				body = body.replace(REGEXES.commands.set_color, "").trim();

				socket.emit('user:set_color:' + room, {
					userColorString: body
				});
				return;
			} else if (matches = body.match(REGEXES.commands.edit)) { // editing
				var mID = matches[2];

				console.log(mID);
				body = body.replace(REGEXES.commands.edit, "").trim();

				socket.emit('chat:edit:' + room, {
					mID: mID,
					body: body
				});

				return;
			} else if (body.match(REGEXES.commands.failed_command)) { // match all
				return;
			} else { // send it out to the world!
				socket.emit('chat:' + room, msg);
			}
		}
	});

});
