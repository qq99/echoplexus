function SyncedEditor () {
	var SyncedEditorView = Backbone.View.extend({
		class: "syncedEditor",

		initialize: function (opts) {
			_.bindAll(this);
			if (!opts.hasOwnProperty("editor")) {
				throw "There was no editor supplied to SyncedEditor";
			}
			if (!opts.hasOwnProperty("room")) {
				throw "There was no room supplied to SyncedEditor";
			}

			this.editor = opts.editor;
			this.channelName = opts.room;
			this.socket = io.connect(window.location.origin);

			this.listen();
			this.attachEvents();
		},

		attachEvents: function () {
			_.each(editors, function (obj) {
				var editor = obj.editor;
				var namespace = obj.namespace;
				
				editor.on("change", function (instance, change) {
					if (change.origin !== undefined && change.origin !== "setValue") {
						socket.emit(namespace + ":code:change", change);
					}
					updateJsEval();
				});
				editor.on("cursorActivity", function (instance) {
					socket.emit(namespace + ":code:cursorActivity", {
						cursor: instance.getCursor()
					});
				});
			});
		},

		listen: function () {
			var self = this;

			this.socketEvents = {
				"code:change": function (change) {
					// received a change from another client, update our view
					applyChanges(change);
				},
				"code:request": function () {
					// received a transcript request from server, it thinks we're authority
					// send a copy of the entirety of our code
					self.socket.emit("code:full_transcript", {
						code: editor.getValue()
					});
				},
				"code:sync": function (data) {
					// hard reset / overwrite our code with the value from the server
					if (self.editor.getValue() !== data.code) {
						self.editor.setValue(data.code);
					}
				},
				"code:authoritative_push": function (data) {
					// received a batch of changes and a starting value to apply those changes to
					self.editor.setValue(data.start);
					for (var i = 0; i < data.ops.length; i ++) {
						applyChanges(data.ops[i]);
					}
				},
				"code:cursorActivity": function (data) {
					// show the other users' cursors in our view
					var pos = self.editor.charCoords(data.cursor); // their position

					// try to find an existing ghost cursor:
					var $ghostCursor = $(".ghost-cursor[rel='" + data.id + "']", this.$el);
					if (!$ghostCursor.length) { // if non-existent, create one
						$ghostCursor = ("<div class='ghost-cursor' rel=" + data.id +"></div>");
						$("body").append($ghostCursor); // it's absolutely positioned wrt body
					}

					// position it:
					// TODO:
					// if view.is.active { show cursor } else { hide }

					$ghostCursor.css({
						background: clients.get(data.id).getColor().toRGB(),
						top: pos.top,
						left: pos.left
					});
				}
			};

			// todo: bind on channel
		},

		applyChanges: function (change) {
			var editor = self.editor;
			
			editor.replaceRange(change.text, change.from, change.to);
			while (change.next !== undefined) { // apply all the changes we receive until there are no more
				change = change.next;
				editor.replaceRange(change.text, change.from, change.to);
			}
		}
	});

	return SyncedEditorView;
}