define(['jquery','underscore','backbone','client','regex',
		'modules/chat/Autocomplete',
		'modules/chat/Scrollback',
		'modules/chat/Log',
		'modules/chat/ChatLog',
		'ui/Growl',
		'text!modules/chat/templates/chatPanel.html'
	],
	function($,_,Backbone,Client,Regex,Autocomplete,Scrollback,Log,ChatLog,Growl,chatpanelTemplate){
	var ColorModel = Client.ColorModel,
		ClientModel = Client.ClientModel,
		ClientsCollection = Client.ClientsCollection,
		REGEXES = Regex.REGEXES;
	return Backbone.View.extend({
		className: "chatChannel",
		template: _.template(chatpanelTemplate),

		initialize: function (opts) {
			var self = this;

			_.bindAll(this);

			this.hidden = true;
			this.socket = io.connect("/chat");
			this.channel = opts.channel;
			this.channel.clients.model = ClientModel;

			this.channelName = opts.room;
			this.autocomplete = new Autocomplete();
			this.scrollback = new Scrollback();
			this.persistentLog = new Log({
				namespace: this.channelName
			});

			this.chatLog = new ChatLog({
				room: this.channelName
			});

			this.me = new ClientModel({
				socket: this.socket
			});
			this.me.persistentLog = this.persistentLog;

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

			// triggered by ChannelSwitcher:
			this.on("show", this.show);
			this.on("hide", this.hide);

		},

		show: function(){
			this.$el.show();
			this.chatLog.scrollToLatest();
			$("textarea", self.$el).focus();
			this.hidden = false;
		},

		hide: function () {
			this.$el.hide();
			this.hidden = true;
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

			this.socket.emit("unsubscribe:" + this.channelName, {
				room: this.channelName
			});
			_.each(this.socketEvents, function (method, key) {
				self.socket.removeAllListeners(key + ":" + self.channelName);
			});
		},

		postSubscribe: function (data) {
			var self = this;
			
			DEBUG && console.log("Subscribed", self.channelName);

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

			// check to see if me.nick is contained in the msgme.
			if (msg.body.toLowerCase().indexOf("@" + this.me.get("nick").toLowerCase()) !== -1) {

				var strippedBody = msg.body.replace("@" + this.me.get("nick"), "");

				// do not alter the message in the following circumstances:
				if (msg.class) {
					if ((msg.class.indexOf("part") !== -1) ||
						(msg.class.indexOf("join") !== -1)) { // don't notify for join/part; it's annoying when anonymous

						return msg; // short circuit
					}
				}

				// alter the message:
				DEBUG && console.log("@me", msg.body);

				if (this.channel.isPrivate) {
					// display more privacy-minded notifications for private channels
					notifications.notify({
						title: "echoplexus",
						body: "There are new unread messages",
						tag: "chatMessage"
					});
				} else {
					// display a full notification for a public channel
					notifications.notify({
						title: msg.nickname + " says:",
						body: strippedBody,
						tag: "chatMessage"
					});
				}
				msg.directedAtMe = true;
			}
			
			if (msg.type !== "SYSTEM") { // count non-system messages as chat activity
				window.events.trigger("chat:activity", {
					channelName: this.channelName
				});

				// do not show a growl for this channel's chat if we're looking at it
				if (OPTIONS.show_growl &&
					(this.hidden || !chatModeActive())) {
					var growl = new Growl({
						title: this.channelName + ":  " + msg.nickname,
						body: msg.body
					});
				}
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
					window.events.trigger("message",socket,self,msg);
					switch (msg.class) {
						case "join":
							var newClient = new ClientModel(msg.client);
							self.channel.clients.add(newClient);
							DEBUG && console.log("users now contains", self.channel.clients);
							break;
						case "part":
							self.channel.clients.remove(msg.id);
							break;
					}

					msg = self.checkToNotify(msg);

					self.persistentLog.add(msg); 
					self.chatLog.renderChatMessage(msg);
				},
				"chat:batch": function (msgs) {
					var msg;
					for (var i = 0, l = msgs.length; i < l; i++) {
						msg = JSON.parse(msgs[i]);

						self.persistentLog.add(msg);
						self.chatLog.renderChatMessage(msg);
					}
				},
				"private_message": function (msg) {
					DEBUG && console.log("private_message:", self.channelName, msg);

					msg = self.checkToNotify(msg);

					self.persistentLog.add(msg);
					self.chatLog.renderChatMessage(msg);
				},
				"private": function () {
					self.channel.isPrivate = true;
					self.autoAuth();
				},
				"subscribed": function () {
					self.postSubscribe();
				},
				"chat:idle": function (msg) {
					DEBUG && console.log(msg);
					$(".user[rel='"+ msg.id +"']", self.$el).append("<span class='idle' data-timestamp='" + Number(new Date()) +"'>Idle</span>");
				},
				"chat:unidle": function (msg) {
					$(".user[rel='"+ msg.id +"'] .idle", self.$el).remove();
				},
				"chat:edit": function (msg) {
					window.events.trigger("message",socket,self,msg);

					msg = self.checkToNotify(msg);

					self.persistentLog.replaceMessage(msg);
					self.chatLog.replaceChatMessage(msg);
				},
				"client:id": function (msg) {
					self.me.set("id", msg.id);
				},
				"userlist": function (msg) {
					DEBUG && console.log("userlist",msg);
					// update the pool of possible autocompletes
					self.autocomplete.setPool(_.map(msg.users, function (user) {
						return user.nick;
					}));
					self.channel.clients.set(msg.users);

					self.chatLog.renderUserlist(self.channel.clients);

					DEBUG && console.log("and stored users are", self.channel.clients);
				},
				"chat:currentID": function (msg) {
					var missed;
					
					self.persistentLog.latestIs(msg.ID); // store the server's current sequence number

					// find out only what we missed since we were last connected to this channel
					missed = self.persistentLog.getListOfMissedMessages();

					// then pull it, if there was anything
					if (missed && missed.length) {
						socket.emit("chat:history_request:" + self.channelName, {
						 	requestRange: missed
						});
					}
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
							window.events.trigger('joinChannel', channelName);
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
						var flattext = $(this).val();

						// don't continue to append auto-complete results on the end
						if (flattext.length >= 1 && 
							flattext[flattext.length-1] === " ") {
							
							return;
						}

						var text = flattext.split(" ");
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
				var missed = self.persistentLog.getMissingIDs(25);
				if (missed && missed.length) {
					self.socket.emit("chat:history_request:" + self.channelName, {
					 	requestRange: missed
					});
				}
			});

			this.$el.on("click", "button.deleteLocalStorage", function (ev) {
				ev.preventDefault();
				self.persistentLog.destroy();
				self.chatLog.clearChat(); // visually reinforce to the user that it deleted them by clearing the chatlog
				self.chatLog.clearMedia(); // "
			});

			this.$el.on("click", "button.clearChatlog", function (ev) {
				ev.preventDefault();
				self.chatLog.clearChat();
			});

			window.events.on("beginEdit:" + this.channelName, function (data) {
				var mID = data.mID,
					msgText,
					msg = self.persistentLog.getMessage(mID); // get the raw message data from our log, if possible

				if (!msg) { // if we didn't have it in our log (e.g., recently cleared storage), then get it from the DOM
					msgText = $(".chatMessage.mine[data-sequence='" + mID + "'] .body").text();
				} else {
					msgText = msg.body;
				}
				$(".chatinput textarea", this.$el).val("/edit #" + mID + " " + msg.body).focus();
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
});