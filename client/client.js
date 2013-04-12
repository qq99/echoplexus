(function( exports ) {
	if (typeof require !== "undefined") { // factor out node stuff
		_ = require('underscore');
	}

	exports.Color = function (options) {
		var _r, _g, _b, _a;

		options = options || {};

		_r = (options.r) ? options.r : parseInt(Math.random()*100+155,10);
		_g = (options.g) ? options.g : parseInt(Math.random()*100+155,10);
		_b = (options.b) ? options.b : parseInt(Math.random()*100+155,10);
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

	exports.Client = function (options) {
		var nick = "Anonymous" || options.nick,
			color = options.color ? new exports.Color(options.color) : new exports.Color(),
			id = options.id || null,
			identified = false,
			socket = options.socketRef,
			isUser = (options.serverSide) ? false : true, // true iff this is a client with UI
			lastActivity = new Date();

		return {
			id: id,
			socket: socket,
			setNick: function(newNickname) {
				nick = newNickname;

				if (isUser) {
					socket.emit("nickname", {
						nickname: newNickname
					});
					$.cookie("nickname", newNickname);
				}
			},
			getColor: function () {
				return color;
			},
			getNick: function() {
				return nick;
			},
			isIdle: function () {
				if (((lastActivity - (new Date())) / (1000*60)) < 5) {
					return false;
				} else {
					return true;
				}
			},
			speak: function (msg) {
				socket.emit('chat', msg);
			},
			active: function () {
				lastActivity = new Date();
			},
			setIdentified: function (isHe) {
				identified = isHe;
			},
			serialize: function () {
				return {
					id: id,
					nick : nick,
					color: color,
					identified: identified
				};
			},
			sendCursor: function (cursorActivity) {
				socket.emit('code:cursorActivity', {
					color: color
				});
			}
		};
	};

	function ID () {
		var cur = 0;
		return {
			next: function () {
				return cur += 1;
			}
		}
	}

	exports.Clients = function () {	
		var id = new ID(); // keep the IDs unique
		var clients = {};
		return {
			add: function (options) {
				if (options.client) {
					if (clients[options.client.id]) return; // don't add twice
					clients[options.client.id] = new exports.Client(options.client);
				} else {
					var ref = id.next();
					clients[ref] = new exports.Client({
						socketRef: options.socketRef,
						id: ref,
						serverSide: true
					});
					return ref;
				}
			},
			get: function (id) {
				return clients[id];
			},
			userlist: function () {
				return _.map(clients, function (value, key, list) {
					return value.serialize();
				});
			},
			kill: function (id) {
				delete clients[id];
			}
		};
	};

})(
  typeof exports === 'object' ? exports : this
);