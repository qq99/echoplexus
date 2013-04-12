(function( exports ) {
	if (typeof require !== "undefined") { // factor out node stuff
		_ = require('underscore');
	}

	exports.Color = function (r,g,b,a) {
		var _r, _g, _b, _a;

		_r = (r) ? r : parseInt(Math.random(255),10);
		_g = (g) ? g : parseInt(Math.random(255),10);
		_b = (b) ? b : parseInt(Math.random(255),10);
		_a = (a) ? a : Math.random();

		return {
			r: _r,
			g: _g,
			b: _b,
			a: _a
		};
	};

	exports.Client = function (options) {
		var nick = "Anonymous" || options.nick,
			color = new exports.Color(),
			id = options.id || null,
			identified = false,
			socket = options.socketRef,
			isUser = (options.serverSide) ? false : true, // true iff this is a client with UI
			lastActivity = new Date();

		return {
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
					clients[options.client.id] = options.client;
				} else {
					var ref = id.next();
					clients[ref] = new exports.Client({
						socketRef: options.socketRef,
						id: id,
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