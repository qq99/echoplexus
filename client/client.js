(function( exports ) {
	if (typeof require !== "undefined") { // factor out node stuff
		_ = require('underscore');
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

	exports.Client = function (options) {
		var nick = "Anonymous" || options.nick,
			color = options.color ? new exports.Color(options.color) : new exports.Color(),
			id = options.id || null,
			identified = false,
			idle = false,
			idleTimer,
			socket = options.socketRef,
			isUser = (options.serverSide) ? false : true, // true iff this is a client with UI
			lastActivity = new Date();

		function announceIdle(reason) {
			reason = reason || "User idle.";
			socket.emit("chat:idle", {
				reason: reason
			});
		}
		function announceBack() {
			socket.emit("chat:unidle");
		}

		return {
			id: function () {
				return id;
			},
			socket: socket,
			setID: function(newId) {
				id = newId;
			},
			setNick: function(newNickname) {
				nick = newNickname;

				if (isUser) {
					socket.emit("nickname", {
						nickname: newNickname
					});
					$.cookie("nickname", newNickname);
				}
			},
			isIdle: function (setIdle) {
				if (typeof setIdle !== "undefined") {

				}
			},
			setIdle: function () {
				idle = true;
			},
			setActive: function () {
				idle = false;
			},
			is: function (cID) {
				console.log(id);
				return (id === cID);
			},
			getColor: function () {
				return color;
			},
			getNick: function() {
				return nick;
			},
			speak: function (msg) {
				socket.emit('chat', msg);
			},
			active: function () {
				console.log("idle", idle);
				if (idle === true) {
					// declare that we're back
					idle = false;
					announceBack();
				} else {
					// attempt to set us to away
					clearTimeout(idleTimer);
					idleTimer = setTimeout(announceIdle, 30000);
				}
			},
			setIdentified: function (isHe) {
				identified = isHe;
			},
			serialize: function () {
				return {
					cID: id,
					idle: idle,
					nick : nick,
					color: color.toRGB(),
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