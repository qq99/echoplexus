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
			this.persistentLog = new Log({
				namespace: this.channelName
			});

			var chatLogView = new ChatLog();
			this.chatLog = new chatLogView({
				room: this.channelName
			});

			this.listen();
			this.render();
			this.attachEvents();

			// if there's something in the persistent chatlog, render it:
			if (!this.persistentLog.empty()) {
				var entries = this.persistentLog.all();
				console.log(entries);
				var renderedEntries = [];
				for (var i = 0, l = entries.length; i < l; i++) {
					var entry = this.chatLog.renderChatMessage(entries[i], {
						delayInsert: true
					});
					renderedEntries.push(entry);
				}
				this.chatLog.insertBatch(renderedEntries);
			}
		},

		render: function () {
			this.$el.html(this.template());
			$(".chatarea", this.$el).html(this.chatLog.$el);
		},

		listen: function () {
			var self = this,
				socket = this.socket;

			function prefilter (msg) {
				if (typeof msg === "undefined") {
					return true;
				}
				if (typeof msg.room === "undefined") {
					console.warn("Message came in but had no channel designated", msg);
				}
				return (msg.room === self.channelName);
			}

			var events = {
				"connect": function () {
					console.log("Connected");
					self.me = new Client({ 
						socketRef: socket
					});
					if ($.cookie("nickname")) {
						self.me.setNick($.cookie("nickname"));
					}
					// this.me.active(); // fix up

					// notifications.enable();
				},
				"chat": function (msg) {
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

					self.persistentLog.add(msg); // TODO: log to a channel
					self.chatLog.renderChatMessage(msg);
				},
				"chat:idle": function (msg) {
					$(".user[rel='"+ msg.cID +"']", self.$el).append("<span class='idle'>Idle</span>");
					if (self.me.is(msg.cID)) {
						self.me.setIdle();
					}
				},
				"chat:unidle": function (msg) {
					$(".user[rel='"+ msg.cID +"'] .idle", self.$el).remove();
				},
				"chat:your_cid": function (msg) {
					self.me.setID(msg.cID);	
				},
				"userlist": function (msg) {
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
				},
				"chat:currentID": function (msg) {
					self.persistentLog.latestIs(msg.ID);
				},
				"topic": function (msg) {
					self.chatLog.setTopic(msg);
				}
			};

			_.each(_.pairs(events), function (pair) {
				var eventName = pair[0];
				var eventAction = pair[1];

				// wrap each event with a simple pre-filter to listen to only those that apply to this object's channel
				var filteredEventAction = _.wrap(eventAction, function (fn) {
					var msg = arguments[1];
					if (!prefilter(msg)) return;
					fn(msg);
				});

				socket.on(eventName, filteredEventAction);
			});

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