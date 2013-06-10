if (typeof DEBUG === 'undefined') DEBUG = true; // will be removed

(function( exports ) {
	if (typeof require !== "undefined") { // factor out node stuff
		_ = require('underscore');
		Backbone = require('backbone');
	}

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
		toRGB: function () {
			return "rgb(" + this.attributes.r + "," + this.attributes.g + "," + this.attributes.b + ")";
		}
	});

	exports.ClientsCollection = Backbone.Collection.extend({
		model: exports.ClientModel
	});

	exports.ClientModel = Backbone.Model.extend({
		defaults: {
			nick: "Anonymous",
			identified: false,
			idle: false,
			isServer: false
		},
		toJSON: function() {
			var json = Backbone.Model.prototype.toJSON.apply(this, arguments);
  			json.cid = this.cid;
			return json;
		},
		initialize: function (opts) {
			DEBUG && console.log(this, opts);
			_.bindAll(this);

			if (opts && opts.color) {
				this.set("color", new exports.ColorModel(opts.color));
			} else {
				this.set("color", new exports.ColorModel());
			}
			if (opts && opts.socket) {
				this.socket = opts.socket;
			}
		},
		channelAuth: function (pw, room) {
			$.cookie("channel_pw:" + room, pw, window.COOKIE_OPTIONS);
			DEBUG && console.log("sending channel pw", pw, room);

			this.socket.emit('join_private:' + room, {
				password: pw,
				room: room
			});
		},
		inactive: function (reason, room, socket) {
			reason = reason || "User idle.";
			DEBUG && console.log("sending inactive msg", room);
			socket.emit("chat:idle:" + room, {
				reason: reason,
				room: room
			});
			this.isInactive = true;
		},
		active: function (room, socket) {
			if (this.isInactive) { // only send over wire if we're inactive
				DEBUG && console.log("sending active msg");
				socket.emit("chat:unidle:" + room);
				this.isInactive = false;
			}
		},
		setNick: function (nick, room, ack) {
			$.cookie("nickname:" + room, nick, window.COOKIE_OPTIONS);
			DEBUG && console.log("sending new nick", nick, room);

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
				room = msg.room;
			window.EventBus.trigger("speak",socket,this,msg);
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

					socket.emit('private_message:' + room, {
						body: body,
						room: room,
						directedAt: targetNick
					});
				}
				return;
			} else if (body.match(REGEXES.commands.failed_command)) { // match all
				return;
			} else { // send it out to the world!
				socket.emit('chat:' + room, msg);
			}
		}
	});

})(
  typeof exports === 'object' ? exports : window
);