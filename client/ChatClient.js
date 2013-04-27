function ChatClient (options) {

	ChatClientView = Backbone.View.extend({

		initialize: function () {
			_.bindAll(this);
			this.socket = io.connect(window.location.origin);
			
			var socket = this.socket,
				self = this;

			this.channels = {};

			socket.on('connect', function () {
				console.log("connected");
				self.me = new Client({ 
					socketRef: socket
				});
				if ($.cookie("nickname")) {
					self.me.setNick($.cookie("nickname"));
				}
				
				// this.me.active(); // fix up

				// notifications.enable();
			});

			socket.on('chat', function (msg) {
				console.log(msg);
				// dispatch to the correct channel:
				var targetChannel = msg.room;

				switch (msg.class) {
					case "join":
						this.channels[targetChannel].userlist.add({
							client: msg.client
						});
						break;
					case "part":
						this.channels[targetChannel].userlist.kill(msg.clientID);
						break;
				}

				console.log(msg);

				// // scan through the message and determine if we need to notify somebody that was mentioned:
				// if (msg.body.toLowerCase().split(" ").indexOf(this.me.getNick().toLowerCase()) !== -1) {
				// 	notifications.notify(msg.nickname, msg.body.substring(0,50));
				// 	msg.directedAtMe = true;
				// }

				// log.add(msg); // TODO: log to a channel
				// chat.renderChatMessage(msg);
				// chat.scroll();
			});

			// socket.on('chat:idle', function (msg) {
			// 	$(".user[rel='"+ msg.cID +"']").append("<span class='idle'>Idle</span>");
			// 	// console.log(this.me.id(), msg.cID);
			// 	if (this.me.is(msg.cID)) {
			// 		this.me.setIdle();
			// 	}
			// });
			// socket.on('chat:unidle', function (msg) {
			// 	// console.log(msg, $(".user[rel='"+ msg.cID +"'] .idle"), $(".user[rel='"+ msg.cID +"'] .idle").length);
			// 	$(".user[rel='"+ msg.cID +"'] .idle").remove();
			// });

			// socket.on('chat:your_cid', function (msg) {
			// 	this.me.setID(msg.cID);
			// });

			// socket.on('userlist', function (msg) {
			// 	// update the pool of possible autocompletes
			// 	autocomplete.setPool(_.map(msg.users, function (user) {
			// 		return user.nick;
			// 	}));

			// 	chat.renderUserlist(msg.users);
			// });

			// socket.on('chat:currentID', function (data) {
			// 	log.latestIs(data.ID);
			// });

			this.attachEvents();
		},
		joinChannel: function (channelName) {
			var channel = new ChatChannel({
				socket: this.socket,
				room: channelName
			});
			this.channels[channelName] = channel;
			console.log("my channels: ", this.channels);
		},
		attachEvents: function () {
			var self = this;
			$("#chatinput textarea").on("keydown", function (ev) {
				$this = $(this);
				switch (ev.keyCode) {
					// enter:
					case 13:
						ev.preventDefault();
						var userInput = $this.val();
						// scrollback.add(userInput);
						// userInput = userInput.split("\n");
						// for (var i = 0, l = userInput.length; i < l; i++) {
						// 	handleChatMessage({
						// 		body: userInput[i]
						// 	});
						// }

						self.me.speak({
							body: userInput
						}, window.location.pathname);
						$this.val("");
						scrollback.reset();
						break;
					// up:
					case 38:
						// $this.val(scrollback.prev());
						break;
					// down
					case 40:
						// $this.val(scrollback.next());
						break;
					// escape
					case 27:
						// scrollback.reset();
						$this.val("");
						break;
					// L
					case 76:
						// if (ev.ctrlKey) {
						// 	ev.preventDefault();
						// 	$("#chatlog .messages").html("");
						// 	$("#linklog .body").html("");
						// }
						break;
					 // tab key
					case 9:
						ev.preventDefault();
						// var text = $(this).val().split(" ");
						// var stub = text[text.length - 1];				
						// var completion = autocomplete.next(stub);

						// if (completion !== "") {
						// 	text[text.length - 1] = completion;
						// }
						// if (text.length === 1) {
						// 	text[0] = text[0] + ", ";
						// }

						// $(this).val(text.join(" "));
						break;
				}

			});
		}
	});

	return ChatClientView;
}