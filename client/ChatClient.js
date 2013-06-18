if (typeof DEBUG === 'undefined') DEBUG = true; // will be removed

function ChatChannel (options) {
	var ChatChannelView = Backbone.View.extend({
		className: "chatChannel",
		template: _.template($("#chatpanelTemplate").html()),

		initialize: function (opts) {
			var self = this;

			_.bindAll(this);

			this.socket = io.connect("/chat");
			this.channelName = opts.room;
			this.autocomplete = new Autocomplete();
			this.users = new ClientsCollection();
			this.users.model = ClientModel;
			this.scrollback = new Scrollback();
			this.persistentLog = new Log({
				namespace: this.channelName
			});

			var chatLogView = new ChatLog();
			this.chatLog = new chatLogView({
				room: this.channelName
			});

			this.me = new ClientModel({
				socket: this.socket
			});

			this.listen();
			this.render();
			this.attachEvents();
			this.bindReconnections(); // Sets up the client for Disconnect messages and Reconnect messages

			// initialize the channel
			this.socket.emit("subscribe", {
				room: self.channelName
			}, this.postSubscribe);

			// if there's something in the persistent chatlog, render it:
			if (!this.persistentLog.empty()) {
				var entries = this.persistentLog.all();
				var renderedEntries = [];
				for (var i = 0, l = entries.length; i < l; i++) {
					var entry = this.chatLog.renderChatMessage(entries[i], {
						delayInsert: true
					});
					renderedEntries.push(entry);
				}
				this.chatLog.insertBatch(renderedEntries);
			}

			this.on("show", function () {
				self.$el.show();
				self.show();
			});

			this.on("hide", function () {
				self.$el.hide();
			});
			this.on("activity", function(){
				if (!chatModeActive()) {
					$("#chatButton").addClass("activity");
				}
			});
		},

		show: function(){
			this.chatLog.scrollToLatest();
			$("textarea", self.$el).focus();
		},

		bindReconnections: function(){
			var self = this;
			//Bind the disconnnections, send message on disconnect
			self.socket.on("disconnect",function(){
				self.chatLog.renderChatMessage({
					body: 'Disconnected from the server',
					type: 'SYSTEM',
					timestamp: new Date().getTime(),
					nickname: '',
					class: 'client'
				});
			});
			//On reconnection attempts, print out the retries
			self.socket.on("reconnecting",function(nextRetry){
				self.chatLog.renderChatMessage({
					body: 'Connection lost, retrying in ' + nextRetry/1000.0 + ' seconds',
					type: 'SYSTEM',
					timestamp: new Date().getTime(),
					nickname: '',
					class: 'client'
				});
			});
			//On successful reconnection, render the chatmessage, and emit a subscribe event
			self.socket.on("reconnect",function(){
				//Resend the subscribe event
				self.socket.emit("subscribe", {
					room: self.channelName
				}, self.postSubscribe);
				if (self.me.get('idle')){
					self.me.inactive("", self.channelName, self.socket);
				}
			});
		},

		kill: function () {
			var self = this;

			_.each(this.socketEvents, function (method, key) {
				self.socket.removeAllListeners(key + ":" + self.channelName);
			});
			this.socket.emit("unsubscribe:" + this.channelName, {
				room: this.channelName
			});
		},

		postSubscribe: function (data) {
			var self = this;
			
			DEBUG && console.log("Subscribed", self.channelName);

			if (data) {
				self.me.cid = data.cid;
			}

			// attempt to automatically /nick and /ident
			$.when(this.autoNick()).done(function () {
				self.autoIdent();
			});
		},

		autoNick: function () {
			var acked = $.Deferred();
			var storedNick = $.cookie("nickname:" + this.channelName);
			if (storedNick) {
				DEBUG && console.log("Auto-nicking", this.channelName, storedNick);
				this.me.setNick(storedNick, this.channelName, acked);
			} else {
				acked.reject();
			}

			return acked.promise();
		},

		autoIdent: function () {
			var acked = $.Deferred();
			var storedIdent = $.cookie("ident_pw:" + this.channelName);
			if (storedIdent) {
				this.me.identify(storedIdent, this.channelName, acked);
			} else {
				acked.reject();
			}
			return acked.promise();
		},

		autoAuth: function () {
			// we only care about the success of this event, but the server already responds
			// explicitly with a success event if it is so
			var storedAuth = $.cookie("channel_pw:" + this.channelName);
			if (storedAuth) {
				DEBUG && console.log("Auto-authing", this.channelName, storedAuth);
				this.me.channelAuth(storedAuth, this.channelName);
			}
		},

		render: function () {
			this.$el.html(this.template());
			$(".chatarea", this.$el).html(this.chatLog.$el);
			this.$el.attr("data-channel", this.channelName);
		},

		checkToNotify: function (msg) {
			// scan through the message and determine if we need to notify somebody that was mentioned:
			if (this.me !== "undefined") {
				// check to see if me.nick is contained in the msgme.
				if (msg.body.toLowerCase().indexOf(this.me.get("nick").toLowerCase()) !== -1) {

					// do not alter the message in the following circumstances:
					if (msg.class) {
						if ((msg.class.indexOf("part") !== -1) ||
							(msg.class.indexOf("join") !== -1)) { // don't notify for join/part; it's annoying when anonymous

							return msg; // short circuit
						}
					}

					// alter the message:
					DEBUG && console.log("@me", msg.body);
					notifications.notify({
						title: msg.nickname + " says:",
						body: msg.body,
						tag: "chatMessage"
					});
					msg.directedAtMe = true;
				}
			}

			
			if (msg.type !== "SYSTEM") { // count non-system messages as chat activity
				this.trigger("activity", {
					channelName: this.channelName
				});
			}

			return msg;
		},

		listen: function () {
			var self = this,
				socket = this.socket;
			DEBUG && console.log(self.channelName, "binding socket listeners");

			this.socketEvents = {
				"chat": function (msg) {
					DEBUG && console.log("onChat:", self.channelName, msg);
					window.EventBus.trigger("message",socket,self,msg);
					switch (msg.class) {
						case "join":
							var newClient = new ClientModel(msg.client);
							newClient.cid = msg.cid;
							self.users.add(newClient);
							DEBUG && console.log("users now contains", self.users);
							break;
						case "part":
							break;
					}

					msg = self.checkToNotify(msg);

					self.persistentLog.add(msg); 
					self.chatLog.renderChatMessage(msg);
				},
				"private_message": function (msg) {
					DEBUG && console.log("private_message:", self.channelName, msg);

					msg = self.checkToNotify(msg);

					self.persistentLog.add(msg);
					self.chatLog.renderChatMessage(msg);
				},
				"private": function () {
					self.autoAuth();
				},
				"subscribed": function () {
					self.postSubscribe();
				},
				"chat:idle": function (msg) {
					DEBUG && console.log(msg);
					$(".user[rel='"+ msg.cID +"']", self.$el).append("<span class='idle' data-timestamp='" + Number(new Date()) +"'>Idle</span>");
				},
				"chat:unidle": function (msg) {
					$(".user[rel='"+ msg.cID +"'] .idle", self.$el).remove();
				},
				"chat:your_cid": function (msg) {
					DEBUG && console.log("my_cid:", msg.cid, "users I know about:", self.users);
					// self.me = self.users.get(msg.cid);
					self.me.cid = msg.cid;
				},
				"userlist": function (msg) {
					DEBUG && console.log("userlist",msg);
					// update the pool of possible autocompletes
					self.autocomplete.setPool(_.map(msg.users, function (user) {
						return user.nick;
					}));
					self.users.set(msg.users);

					self.chatLog.renderUserlist(self.users);

					DEBUG && console.log("and stored users are", self.users);
				},
				"chat:currentID": function (msg) {
					self.persistentLog.latestIs(msg.ID);
				},
				"topic": function (msg) {
					self.chatLog.setTopic(msg);
				}
			};

			_.each(this.socketEvents, function (value, key) {
				// listen to a subset of event
				socket.on(key + ":" + self.channelName, value);
			});
		},
		attachEvents: function () {
			var self = this;
			$("body").on("chatSectionActive",function(){
				self.show();
			});
			this.$el.on("keydown", ".chatinput textarea", function (ev) {
				if (ev.ctrlKey || ev.shiftKey) return; // we don't fire any events when these keys are pressed
				
				var $this = $(this);
				switch (ev.keyCode) {
					// enter:
					case 13:
						ev.preventDefault();
						var userInput = $this.val();
						self.scrollback.add(userInput);

						if (userInput.match(REGEXES.commands.join)) { // /join [channel_name]
							channelName = userInput.replace(REGEXES.commands.join, "").trim();
							self.trigger('joinChannel', channelName);
						} else {
							self.me.speak({
								body: userInput,
								room: self.channelName
							}, self.socket);
						}

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
							text[0] = text[0];
						}

						$(this).val(text.join(" "));
						break;
				}

			});

			$(window).on("keydown mousemove", function () {
				if (self.$el.is(":visible")) {
					if (self.me) {
						self.me.active(self.channelName, self.socket);
						clearTimeout(self.idleTimer);
						self.startIdleTimer();						
					}
				}
			});

			this.startIdleTimer();

			this.$el.on("click", "button.syncLogs", function (ev) {
				ev.preventDefault();
				var missed = self.persistentLog.getMissingIDs(10);
				if (missed.length) {
					self.socket.emit("chat:history_request:" + self.channelName, {
					 	requestRange: missed
					});
				}
			});

			this.$el.on("click", "button.deleteLocalStorage", function (ev) {
				ev.preventDefault();
				self.persistentLog.destroy();
				self.chatLog.clear(); // visually reinforce to the user that it deleted them by clearing the chatlog
			});

			this.$el.on("click", "button.clearChatlog", function (ev) {
				ev.preventDefault();
				self.chatLog.clear();
			});
		},

		startIdleTimer: function () {
			var self = this;
			this.idleTimer = setTimeout(function () {
				DEBUG && console.log("setting inactive");
				if (self.me) {
					self.me.inactive("", self.channelName, self.socket);
				}
			}, 1000*30);
		}
	});

	return ChatChannelView;
}