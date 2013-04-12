(function( exports ) {

	exports.Clients = function () {	
		function ID () {
			var cur = 0;
			return {
				next: function () {
					return cur += 1;
				}
			}
		}

		var id = new ID();
		var clients = {};
		return {
			add: function (socketRef) {
				var ref = id.next();
				clients[ref] = new exports.Client({
					socketRef: socketRef,
					cid: id,
					serverSide: true
				});
				return ref;
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