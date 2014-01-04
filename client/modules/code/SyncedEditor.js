define(['jquery','underscore','backbone','client'],function($,_,Backbone,Client){
	return function() {
		var ColorModel = Client.ColorModel,
			ClientsCollection = Client.ClientsCollection,
			ClientModel = Client.ClientModel;
		var SyncedEditorView = Backbone.View.extend({
			class: "syncedEditor",

			initialize: function (opts) {
				var self = this;

				_.bindAll(this);
				if (!opts.hasOwnProperty("editor")) {
					throw "There was no editor supplied to SyncedEditor";
				}
				if (!opts.hasOwnProperty("room")) {
					throw "There was no room supplied to SyncedEditor";
				}

				this.editor = opts.editor;
				this.clients = opts.clients;
				this.channelName = opts.room;
				this.subchannelName = opts.subchannel;
				this.channelKey = this.channelName + ":" + this.subchannelName;
				this.socket = io.connect(opts.host + "/code");

				this.active = false;
				this.listen();
				this.attachEvents();

				// initialize the channel
				this.socket.emit("subscribe", {
					room: this.channelName,
					subchannel: this.subchannelName
				}, this.postSubscribe);

				this.on("show", function () {
					self.active = true;
					if (self.editor) {
						self.editor.refresh();
					}
				});

				this.on("hide", function () {
					self.active = false;
					$(".ghost-cursor").remove();
				});

				// remove their ghost-cursor when they leave
				this.clients.on("remove", function (model) {
					$(".ghost-cursor[rel='" + self.channelKey + model.get("id") + "']").remove();
				});

				$("body").on("codeSectionActive", function () { // sloppy, forgive me
					self.trigger("eval");
				});
			},

			postSubscribe: function () {

			},

			kill: function () {
				var self = this;

				DEBUG && console.log("killing SyncedEditorView");

				_.each(this.socketEvents, function (method, key) {
					self.socket.removeAllListeners(key + ":" + self.channelKey);
				});
				this.socket.emit("unsubscribe:" + this.channelKey, {
					room: this.channelName
				});
			},

			attachEvents: function () {
				var self = this,
					socket = this.socket;
					
				this.editor.on("change", function (instance, change) {
					if (change.origin !== undefined && change.origin !== "setValue") {
						console.log(self.channelKey);
						socket.emit("code:change:" + self.channelKey, change);
					}
					if (codingModeActive()) {
						self.trigger("eval");
					}
				});
				this.editor.on("cursorActivity", function (instance) {
					if (!self.active ||
						!codingModeActive() ) {

						return;	 // don't report cursor events if we aren't looking at the document
					}
					socket.emit("code:cursorActivity:" + self.channelKey, {
						cursor: instance.getCursor()
					});
				});
			},

			listen: function () {
				var self = this,
					editor = this.editor,
					socket = this.socket;

				this.socketEvents = {
					"code:change": function (change) {
						// received a change from another client, update our view
						self.applyChanges(change);
					},
					"code:request": function () {
						// received a transcript request from server, it thinks we're authority
						// send a copy of the entirety of our code
						socket.emit("code:full_transcript:" + self.channelKey, {
							code: editor.getValue()
						});
					},
					"code:sync": function (data) {
						// hard reset / overwrite our code with the value from the server
						if (editor.getValue() !== data.code) {
							editor.setValue(data.code);
						}
					},
					"code:authoritative_push": function (data) {
						// received a batch of changes and a starting value to apply those changes to
						editor.setValue(data.start);
						for (var i = 0; i < data.ops.length; i ++) {
							self.applyChanges(data.ops[i]);
						}
					},
					"code:cursorActivity": function (data) { // show the other users' cursors in our view
						if (!self.active || !codingModeActive()) {
							return;
						}

						var pos = editor.cursorCoords(data.cursor, "local"); // their position

						var fromClient = self.clients.get(data.id); // our knowledge of their client object
						if (fromClient === null) {
							return; // this should never happen
						}

						// try to find an existing ghost cursor:
						var $ghostCursor = $(".ghost-cursor[rel='" + self.channelKey + data.id + "']"); // NOT SCOPED: it's appended and positioned absolutely in the body!
						if (!$ghostCursor.length) { // if non-existent, create one
							$ghostCursor = $("<div class='ghost-cursor' rel=" + self.channelKey + data.id + "></div>");
							$(editor.getWrapperElement()).find(".CodeMirror-lines > div").append($ghostCursor);

							$ghostCursor.append("<div class='user'>"+ fromClient.get("nick") +"</div>");
						}

						var clientColor = fromClient.get("color").toRGB();

						$ghostCursor.css({
							background: clientColor,
							color: clientColor,
							top: pos.top,
							left: pos.left
						});
					}
				};

				_.each(this.socketEvents, function (value, key) {
					socket.on(key + ":" + self.channelKey, value);
				});
				//On successful reconnect, attempt to rejoin the room
				socket.on("reconnect",function(){
					//Resend the subscribe event
					socket.emit("subscribe", {
						room: self.channelName,
						subchannel: self.subchannelName,
						reconnect: true
					});
				});
			},

			applyChanges: function (change) {
				var editor = this.editor;
				
				editor.replaceRange(change.text, change.from, change.to);
				while (change.next !== undefined) { // apply all the changes we receive until there are no more
					change = change.next;
					editor.replaceRange(change.text, change.from, change.to);
				}
			}
		});

		return SyncedEditorView;
	}
});