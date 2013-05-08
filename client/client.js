if (typeof DEBUG === 'undefined') DEBUG = true; // will be removed

(function( exports ) {
	if (typeof require !== "undefined") { // factor out node stuff
		_ = require('underscore');
		Backbone = require('backbone');
	}

	exports.Color = function (options) {
		var _r, _g, _b, _a;

		options = options || {};

		_r = (options.r) ? options.r : parseInt(Math.random()*155+100,10);
		_g = (options.g) ? options.g : parseInt(Math.random()*155+100,10);
		_b = (options.b) ? options.b : parseInt(Math.random()*155+100,10);
		_a = (options.a) ? options.a : Math.random();

		return {
			r: _r,
			g: _g,
			b: _b,
			a: _a,
			toRGB: function () {
				return "rgb(" + _r + "," + _g + "," + _b + ")";
			},
			toRGBA: function () {
				return "rgb(" + _r + "," + _g + "," + _b + "," + _a + ")";
			}
		};
	};

	exports.ColorModel = Backbone.Model.extend({
		defaults: {
			r: 0,
			g: 0,
			b: 0
		},
		initialize: function () {
			this.set("r", parseInt(Math.random()*155+100,10));
			this.set("g", parseInt(Math.random()*155+100,10));
			this.set("b", parseInt(Math.random()*155+100,10));
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

			this.set("color", new exports.ColorModel());
			if (opts && opts.socket) {
				this.socket = opts.socket;
			}
		},
		channelAuth: function (pw, room) {
			$.cookie("channel_pw:" + room, pw);
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
			$.cookie("nickname:" + room, nick);
			DEBUG && console.log("sending new nick", nick, room);
			this.socket.emit('nickname:' + room, {
				nickname: nick
			}, function () {
				if (ack) {
					ack.resolve();
				}
			});
		},
		identify: function (pw, room, ack) {
			$.cookie("ident_pw:" + room, pw);
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

			if (!body) return; // if there's no body, we probably don't want to do anything
			if (body.match(REGEXES.commands.nick)) { // /nick [nickname]
				body = body.replace(REGEXES.commands.nick, "").trim();
				this.setNick(body, room);
				$.cookie("nickname:" + room, body);
				$.cookie("ident_pw:" + room, ""); // clear out the old saved nick
				return;
			} else if (body.match(REGEXES.commands.private)) {  // /private [password]
				body = body.replace(REGEXES.commands.private, "").trim();
				socket.emit('make_private:' + room, {
					password: body,
					room: room
				});
				$.cookie("channel_pw:" + room, body);
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
				$.cookie("ident_pw:" + room, body);
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
			} else if (body.match(REGEXES.commands.failed_command)) { // match all
				return;
			} else { // send it out to the world!
				socket.emit('chat:' + room, msg);
			}
		}
	});

})(
  typeof exports === 'object' ? exports : this
);