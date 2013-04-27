function ChatClient (options) {

	var ChatClientView = Backbone.View.extend({
		template: _.template($("#chatpanelTemplate").html()),

		initialize: function () {
			var self = this;

			_.bindAll(this);

			this.socket = io.connect(window.location.origin);
			this.channelName = window.location.pathname;
			this.channel = new ChatChannel({
				socket: this.socket,
				room: this.channelName
			});
			this.autocomplete = new Autocomplete();
			this.users = new Clients();
			this.scrollback = new Scrollback();

			var chatLogView = new ChatLog();
			this.chatLog = new chatLogView({
				room: this.channelName
			});

			this.listen();
			this.render();
			this.attachEvents();
		},

		render: function () {
			this.$el.html(this.template());
			$(".chatarea", this.$el).html(this.chatLog.$el);
		},

		listen: function () {
			var self = this,
				socket = this.socket;

			function prefilter (msg) {
				if (typeof msg.room === "undefined") {
					console.warn("Message came in but had no channel designated", msg);
				}
				return (msg.room === self.channelName);
			}

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
				if (!prefilter(msg)) return;

				switch (msg.class) {
					case "join":
						self.channel.userlist.add({
							client: msg.client
						});
						break;
					case "part":
						self.channel.userlist.kill(msg.clientID);
						break;
				}

				console.log(msg);

				// // scan through the message and determine if we need to notify somebody that was mentioned:
				// if (msg.body.toLowerCase().split(" ").indexOf(this.me.getNick().toLowerCase()) !== -1) {
				// 	notifications.notify(msg.nickname, msg.body.substring(0,50));
				// 	msg.directedAtMe = true;
				// }

				// log.add(msg); // TODO: log to a channel
				self.chatLog.renderChatMessage(msg);
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

			socket.on('userlist', function (msg) {
				if (!prefilter(msg)) return;

				// update the pool of possible autocompletes
				self.autocomplete.setPool(_.map(msg.users, function (user) {
					return user.nick;
				}));
				self.chatLog.renderUserlist(msg.users);

				_.each(msg.users, function (user) {
					// add to our list of clients
					self.users.add({
						client: user
					});
				});
			});

			// socket.on('chat:currentID', function (data) {
			// 	log.latestIs(data.ID);
			// });
		},
		attachEvents: function () {
			var self = this;
			$(this.$el).on("keydown", ".chatinput textarea", function (ev) {
				$this = $(this);
				switch (ev.keyCode) {
					// enter:
					case 13:
						ev.preventDefault();
						var userInput = $this.val();
						self.scrollback.add(userInput);
						self.me.speak({
							body: userInput
						}, window.location.pathname);
						$this.val("");
						self.scrollback.reset();
						break;
					// up:
					case 38:
						$this.val(self.scrollback.prev());
						break;
					// down
					case 40:
						$this.val(self.scrollback.next());
						break;
					// escape
					case 27:
						self.scrollback.reset();
						$this.val("");
						break;
					 // tab key
					case 9:
						ev.preventDefault();
						var text = $(this).val().split(" ");
						var stub = text[text.length - 1];				
						var completion = self.autocomplete.next(stub);

						if (completion !== "") {
							text[text.length - 1] = completion;
						}
						if (text.length === 1) {
							text[0] = text[0] + ", ";
						}

						$(this).val(text.join(" "));
						break;
				}

			});
		}
	});

	return ChatClientView;
}