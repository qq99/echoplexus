function ChatChannel (options) {
	var channelName = options.room,
		socket = options.socket;

	if (typeof channelName === "undefined") {
		throw "Undefined channel name";
	}
	if (typeof socket === "undefined") {
		throw "Undefined socket";
	}

	// provide ROA
	this.socket = function () {
		return socket;
	};
	this.channelName = function () {
		return channelName();
	};

	// public access:
	this.userlist = new Clients();

	// initialize the channel
	socket.emit("subscribe", {
		room: channelName
	});
}

ChatChannel.prototype.leave = function () {
	this.socket().emit("unsubscribe", {
		room: this.channelName()
	});
};