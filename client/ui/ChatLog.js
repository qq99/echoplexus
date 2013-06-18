if (typeof DEBUG === 'undefined') DEBUG = true; // will be removed

function ChatLog (options) {
	"use strict";

	function makeYoutubeURL(s) {
		var start = s.indexOf("v=") + 2;
		var end = s.indexOf("&", start);
		if (end === -1) {
			end = s.length;
		}
		return window.location.protocol + "//youtube.com/v/" + s.substring(start,end);
	}

	var ChatLogView = Backbone.View.extend({
		className: "channel",
		// templates:
		template: _.template($("#chatareaTemplate").html()),
		chatMessageTemplate: _.template($("#chatMessageTemplate").html()),
		linkedImageTemplate: _.template($("#linkedImageTemplate").html()),
		userTemplate: _.template($("#userListUserTemplate").html()),
		youtubeTemplate: _.template($("#youtubeTemplate").html()),

        initialize: function (options) {
        	_.bindAll(this);
        	
        	if (!options.room) {
        		throw "No channel designated for the chat log";
        	}
        	this.room = options.room;

        	this.uniqueURLs = {};

        	this.render();
        	this.attachEvents();
        },

        render: function () {
        	this.$el.html(this.template({
        		roomName: this.room
        	}));
        },

        attachEvents: function () {
        	// show "Sent ___ ago" when hovering all chat messages:
			this.$el.on("hover", ".chatMessage", function (ev) {
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

        scrollToLatest: function () {
			$(".messages", this.$el).scrollTop($(".messages", this.$el)[0].scrollHeight);
		},

		renderChatMessage: function (msg, opts) {
			var self = this;
			var body = msg.body;

			if (typeof opts === "undefined") {
				opts = {};
			}
			
			if (msg.class !== "identity") { // setting nick to a image URL or youtube URL should not update media bar
				// put image links on the side:
				var images;
				if (OPTIONS["autoload_media"] && (images = body.match(REGEXES.urls.image))) {
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
				if (OPTIONS["autoload_media"] && (youtubes = body.match(REGEXES.urls.youtube))) {
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
			}

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
					color: msg.color,
					body: body,
					humanTime: moment(msg.timestamp).format('hh:mm:ss'),
					timestamp: msg.timestamp,
					classes: chatMessageClasses,
					nickClasses: nickClasses,
					isPrivateMessage: (msg.type && msg.type === "private"),
					directedAt: msg.directedAt
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
			DEBUG && console.log("Inserting chat message", opts);
			var $chatMessage = $(opts.html);
			var $chatlog = $(".messages", this.$el);
			if (opts.timestamp) {
				var timestamps = _.map($(".messages .time", this.$el), function (ele) {
					return $(ele).data("timestamp");
				});

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

				DEBUG && console.log(timestamps, candidate);

				if ($target.length) { // it was in the DOM, so we can insert the current message after it
					DEBUG && console.log('target found');
					$target.last().after($chatMessage); // .last() just in case there can be more than one.... it seems this may have happened once, hopefully by glitch alone
				} else { // it was the first message OR something went wrong
					DEBUG && console.log('something went wrong');
					$chatlog.append($chatMessage);
				}
			} else { // if there was no timestamp, assume it's a diagnostic message of some sort that should be displayed at the most recent spot in history
				DEBUG && console.log("not timestamp");
				$chatlog.append($chatMessage);
			}
			if (OPTIONS['auto_scroll']){
				this.scrollToLatest();
			}
		},

		clear: function () {
			var $chatlog = $(".messages", this.$el);
			$chatlog.html("");
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
}