
define(['jquery','backbone', 'underscore','regex','moment',
	'text!modules/chat/templates/chatArea.html',
	'text!modules/chat/templates/chatMessage.html',
	'text!modules/chat/templates/linkedImage.html',
	'text!modules/chat/templates/userListUser.html',
	'text!modules/chat/templates/youtube.html'
],function($, Backbone, _, Regex, moment,
	chatareaTemplate,
	chatMessageTemplate,
	linkedImageTemplate,
	userListUserTemplate,
	youtubeTemplate){
	var REGEXES = Regex.REGEXES;
	function makeYoutubeURL(s) {
		var matches = REGEXES.urls.youtube.exec(s);
		REGEXES.urls.youtube.exec("");
		//If this function was called, the regex will have matched (aka it must have a v= match)
		return window.location.protocol + "//youtube.com/v/" + matches[5];
	}

	var ChatLogView = Backbone.View.extend({
		className: "channel",
		// templates:
		template: _.template(chatareaTemplate),
		chatMessageTemplate: _.template(chatMessageTemplate),
		linkedImageTemplate: _.template(linkedImageTemplate),
		userTemplate: _.template(userListUserTemplate),
		youtubeTemplate: _.template(youtubeTemplate),

		events: {
			"click .clearMediaLog": "clearMedia",
			"click .disableMediaLog": "disallowMedia",
			"click .maximizeMediaLog": "unminimizeMediaLog",
			"click .media-opt-in .opt-in": "allowMedia",
			"click .media-opt-in .opt-out": "disallowMedia",
			"click .chatMessage-edit": "beginEdit",
			"blur .body[contenteditable='true']": "stopInlineEdit",
			"keydown .body[contenteditable='true']": "onInlineEdit",
			"dblclick .chatMessage.me": "beginInlineEdit"
		},

        initialize: function (options) {
        	var preferredAutoloadSetting;

        	_.bindAll(this);
			this.scrollToLatest = _.debounce(this._scrollToLatest, 100); // if we're pulling a batch, do the scroll just once

        	if (!options.room) {
        		throw "No channel designated for the chat log";
        	}
        	this.room = options.room;

        	this.uniqueURLs = {};

        	this.autoloadMedia = null; // the safe default

        	preferredAutoloadSetting = window.localStorage.getItem("autoloadMedia:" + this.room);
			if (preferredAutoloadSetting) { // if a saved setting exists
				if (preferredAutoloadSetting === "true") {
					this.autoloadMedia = true;
				} else {
					this.autoloadMedia = false;
				}
			}

        	this.render();
        	this.attachEvents();
        },

        beginInlineEdit: function (ev) {
        	var $chatMessage = $(ev.target).parents(".chatMessage"),
        		oldText = $chatMessage.find(".body").text().trim();

        	// store the old text with the node
        	$chatMessage.data('oldText', oldText);

        	// make the entry editable
        	$chatMessage.find(".body")
        		.attr("contenteditable", "true")
        		.focus();
        },

        stopInlineEdit: function (ev) {
        	$(ev.target).removeAttr("contenteditable").blur();
        },

        onInlineEdit: function (ev) {
        	if (ev.ctrlKey || ev.shiftKey) return; // we don't fire any events when these keys are pressed

        	var $this = $(ev.target),
        		$chatMessage = $this.parents(".chatMessage"),
        		oldText = $chatMessage.data("oldText"),
        		mID = $chatMessage.data("sequence");

			switch (ev.keyCode) {
				// enter:
				case 13:
					ev.preventDefault();
					var userInput = $this.text().trim();

					if (userInput !== oldText) {
						window.events.trigger("edit:commit:" + this.room, {
							mID: mID,
							newText: userInput
						});
						this.stopInlineEdit(ev);
					} else {
						this.stopInlineEdit(ev);
					}

					break;
				// escape
				case 27:
					this.stopInlineEdit(ev);
					break;
			}
        },

        render: function () {
        	var linklogClasses = "",
        		userlistClasses = "",
        		optInClasses = "";

        	if (this.autoloadMedia === true) {
        		optInClasses = "hidden";
        	} else if (this.autoloadMedia === false) {
        		linklogClasses = "minimized";
        		userlistClasses = "maximized";
        	} else { // user hasn't actually made a choice (null value)
        		linklogClasses = "not-initialized";
        	}

        	this.$el.html(this.template({
        		roomName: this.room,
        		linklogClasses: linklogClasses,
        		optInClasses: optInClasses,
        		userlistClasses: userlistClasses
        	}));
        },

        unminimizeMediaLog: function () { // nb: not the opposite of maximize
        	// resets the state to the null choice
        	// slide up the media tab (if it was hidden)
        	$(".linklog", this.$el).removeClass("minimized").addClass("not-initialized");
        	$(".userlist", this.$el).removeClass("maximized");
        	$(".media-opt-in", this.$el).fadeIn();
        },

        disallowMedia: function () {
        	this.autoloadMedia = false;
        	this.clearMedia();
        	window.localStorage.setItem("autoloadMedia:" + this.room, false);

        	// slide down the media tab to make more room for the Users tab
        	$(".linklog", this.$el).addClass("minimized").removeClass("not-initialized");
        	$(".userlist", this.$el).addClass("maximized");
        },

        allowMedia: function () {
        	$(".media-opt-in", this.$el).fadeOut();

        	this.autoloadMedia = true;
        	window.localStorage.setItem("autoloadMedia:" + this.room, true);

        	$(".linklog", this.$el).removeClass("not-initialized");
        },

        beginEdit: function (ev) {
        	var mID = $(ev.target).parents(".chatMessage").data("sequence");
        	if (mID) {
        		window.events.trigger("beginEdit:" + this.room, {
        			mID: mID
        		});
        	}
        },

        attachEvents: function () {
        	// show "Sent ___ ago" when hovering all chat messages:
			this.$el.on("mouseenter", ".chatMessage", function (ev) {
				$(this).attr("title", "sent " + moment($(".time", this).data("timestamp")).fromNow());
			});

			// media item events:
			// remove it from view on close button
			this.$el.on("click", ".close", function (ev) {
				var $button = $(this);
				$button.closest(".media-item").remove();
			});

			// minimize/maximize the media item
			this.$el.on("click", ".hide, .show", function (ev) {
				var $button = $(this);

				$button.toggleClass("hide").toggleClass("show");
				// change the icon
				$button.find("i").toggleClass("icon-collapse-alt").toggleClass("icon-expand-alt");
				// toggle the displayed view (.min|.max)
				$button.closest(".media-item").toggleClass("minimized");

				// update the text
				if ($button.hasClass("hide")) {
					$button.find(".explanatory-text").text("Hide");
				} else {
					$button.find(".explanatory-text").text("Show");
				}

			});
        },

        _scrollToLatest: function () { //Get the last message and scroll that into view
        	// can't simply use last-child, since the last child may be display:none
        	// if the user is hiding join/part
        	var latestMessage = ($('.messages .chatMessage:visible',this.$el).last())[0]; // so we get all visible, then take the last of that
			if (typeof latestMessage !== "undefined") {
				console.log("not undefined");
				latestMessage.scrollIntoView();
			}
		},

        replaceChatMessage: function (msg) {
        	var msgHtml = this.renderChatMessage(msg, {delayInsert: true}), // render the altered message, but don't insert it yet
        		$oldMsg = $(".chatMessage[data-sequence='" + msg.mID + "']", this.$el);

        	$oldMsg.after(msgHtml);
        	$oldMsg.remove();
        },

		renderChatMessage: function (msg, opts) {
			var self = this;
			var body = msg.body;

			if (typeof opts === "undefined") {
				opts = {};
			}
			
			if (this.autoloadMedia &&
				msg.class !== "identity") { // setting nick to a image URL or youtube URL should not update media bar
				// put image links on the side:
				var images;
				if (images = body.match(REGEXES.urls.image)) {
					for (var i = 0, l = images.length; i < l; i++) {
						var href = images[i];

						// only do it if it's an image we haven't seen before
						if (self.uniqueURLs[href] === undefined) {
							var img = self.linkedImageTemplate({
								url: href,
								linker: msg.nickname
							});
							$(".linklog .body", this.$el).prepend(img);
							self.uniqueURLs[href] = true;
						}
					}

					body = body.replace(REGEXES.urls.image, "").trim(); // remove the URLs
				}

				// put youtube linsk on the side:
				var youtubes;
				if (youtubes = body.match(REGEXES.urls.youtube)) {
					for (var i = 0, l = youtubes.length; i < l; i++) {
						var src = makeYoutubeURL(youtubes[i]),
							yt = self.youtubeTemplate({
								src: src,
								originalSrc: youtubes[i]
							});
						if (self.uniqueURLs[src] === undefined) {
							$(".linklog .body", this.$el).prepend(yt);
							self.uniqueURLs[src] = true;
						}
					}
				}

				// put hyperlinks on the side:
				var links;
				if (links = body.match(REGEXES.urls.all_others)) {
					for (var i = 0, l = links.length; i < l; i++) {
						if (self.uniqueURLs[links[i]] === undefined) {
							$(".linklog .body", this.$el).prepend("<a href='" + links[i] + "' target='_blank'>" + links[i] + "</a>");
							self.uniqueURLs[links[i]] = true;
						}
					}
				}
			} // end media insertion

			// sanitize the body:
			body = _.escape(body);

			// convert new lines to breaks:
			if (body.match(/\n/g)) {
				var lines = body.split(/\n/g);
				body = "";
				_.each(lines, function (line) {
					line = "<pre>" + line + "</pre>";
					body += line;
				});
			}

			// hyperify hyperlinks for the chatlog:
			body = body.replace(REGEXES.urls.all_others,'<a target="_blank" href="$1">$1</a>');
			body = body.replace(REGEXES.users.mentions,'<span class="mention">$1</span>');
			if (body.length) { // if there's anything left in the body, 
				var chatMessageClasses = "";
				var nickClasses = "";
				// special styling of chat
				if (msg.directedAtMe) {
					chatMessageClasses += "highlight ";
				}
				if (msg.type === "SYSTEM") {
					nickClasses += "system ";
				}
				if (msg.class) {
					chatMessageClasses += msg.class;
				}
				// special styling of nickname depending on who you are:
				if (msg.you) { // if it's me!
					chatMessageClasses += " me ";
				}

				var chat = self.chatMessageTemplate({
					nickname: msg.nickname,
					mID: msg.mID,
					color: msg.color,
					body: body,
					humanTime: moment(msg.timestamp).format('hh:mm:ss'),
					timestamp: msg.timestamp,
					classes: chatMessageClasses,
					nickClasses: nickClasses,
					isPrivateMessage: (msg.type && msg.type === "private"),
					directedAt: msg.directedAt,
					mine: (msg.you ? true : false),
					identified: (msg.identified ? true : false)
				});

				if (!opts.delayInsert) {
					self.insertChatMessage({
						timestamp: msg.timestamp,
						html: chat
					});
				}

				return chat;
			}
		},
		insertBatch: function (htmls) {
			$(".messages", this.$el).append(htmls.join(""));
			$(".chatMessage", this.$el).addClass("fromlog");
		},

		insertChatMessage: function (opts) {
			// insert msg into the correct place in history
			var $chatMessage = $(opts.html);
			var $chatlog = $(".messages", this.$el);
			if (opts.timestamp) {
				var timestamps = _.map($(".messages .time", this.$el), function (ele) {
					return $(ele).data("timestamp");
				}); // assumed invariant: timestamps are in ascending order

				var cur = opts.timestamp,
					candidate = -1;
				
				$chatMessage.attr("rel", cur);
				// find the earliest message we know of that's before the message we're about to render
				for (var i = timestamps.length - 1; i >= 0; i--) {
					candidate = timestamps[i];
					if (cur > timestamps[i]) break;
				}
				// attempt to select this early message:
				var $target = $(".chatlog .chatMessage[rel='"+ candidate +"']", this.$el);
				if ($target.length) { // it was in the DOM, so we can insert the current message after it
					if (i === -1) {
						$target.last().before($chatMessage); // .last() just in case there can be more than one $target
					} else {
						$target.last().after($chatMessage); // .last() just in case there can be more than one $target
					}
				} else { // it was the first message OR something went wrong
					$chatlog.append($chatMessage);
				}
			} else { // if there was no timestamp, assume it's a diagnostic message of some sort that should be displayed at the most recent spot in history
				$chatlog.append($chatMessage);
			}
			if (OPTIONS['auto_scroll']){
				this.scrollToLatest();
			}
		},

		clearChat: function () {
			var $chatlog = $(".messages", this.$el);
			$chatlog.html("");
		},

		clearMedia: function () {
			var $mediaPane = $(".linklog .body", this.$el);
			$mediaPane.html("");
		},

		renderUserlist: function (users) {
			var self = this, 
				$userlist = $(".userlist .body", this.$el);

			if (users) { // if we have users
				// clear out the userlist
				$userlist.html("");
				var userHTML = "";
				var nActive = 0;
				var total = 0;
				_.each(users.models, function (user) {
					// add him to the visual display
					var userItem = self.userTemplate({
						nick: user.get("nick"),
						cid: user.cid,
						color: user.get("color").toRGB(),
						identified: user.get("identified"),
						idle: user.get("idle"),
						idleSince: user.get("idleSince")
					});
					if (!user.get('idle')) {
						nActive += 1;
					}
					total += 1;
					userHTML += userItem;
				});
				$userlist.append(userHTML);

				$(".userlist .count .active .value", this.$el).html(nActive);
				$(".userlist .count .total .value", this.$el).html(total);
			} else {
				// there's always gonna be someone...
			}
		},

		setTopic: function (msg) {
			$(".channel-topic .value", this.$el).html(msg.body);
		}
	});
	return ChatLogView;
});