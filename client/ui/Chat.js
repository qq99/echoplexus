function Chat () {
	"use strict";
	// templates:
	var chatMessageTemplate = _.template($("#chatMessageTemplate").html()),
		linkedImageTemplate = _.template($("#linkedImageTemplate").html()),
		userTemplate = _.template($("#userListUserTemplate").html()),
		fl_obj_template = '<object>' +
                  '<param name="movie" value=""></param>' +   
                  '<param name="allowFullScreen" value="true"></param>' +   
                  '<param name="allowscriptaccess" value="always"></param>' +   
                  '<embed src="" type="application/x-shockwave-flash" allowscriptaccess="always" allowfullscreen="true" width="274" height="200"></embed>' +   
                  '</object>',
		// containers:
		$chatlog = $("#chatlog .messages"),
		$userlist = $("#userlist .body"),
		// cache:
		timestampsSeenSoFar = [];

	function makeYoutubeURL(s) {
		var start = s.indexOf("v=") + 2;
		var end = s.indexOf("&", start);
		if (end === -1) {
			end = s.length;
		}
		return "http://youtube.com/v/" + s.substring(start,end);
	}

	this.scroll = function () {
		$chatlog.scrollTop($chatlog[0].scrollHeight);
	};

	this.renderChatMessage = function (msg, opts) {
		var body = msg.body;

		if (typeof opts === "undefined") {
			opts = {};
		}
		// console.log(msg.cID, session.id());

		// put image links on the side:
		var images;
		if (OPTIONS["autoload_media"] && (images = body.match(REGEXES.urls.image))) {
			for (var i = 0, l = images.length; i < l; i++) {
				var href = images[i];

				// only do it if it's an image we haven't seen before
				if (uniqueImages[href] === undefined) {
					var img = linkedImageTemplate({
						url: href,
						linker: msg.nickname
					});
					$("#linklog .body").prepend(img);
					uniqueImages[href] = true;
				}
			}

			body = body.replace(REGEXES.urls.image, "").trim(); // remove the URLs
		}

		// put youtube linsk on the side:
		var youtubes;
		if (OPTIONS["autoload_media"] && (youtubes = body.match(REGEXES.urls.youtube))) {
			for (var i = 0, l = youtubes.length; i < l; i++) {
				var src = makeYoutubeURL(youtubes[i]),
					yt = $(fl_obj_template);
				if (uniqueImages[src] === undefined) {
					yt.find("embed").attr("src", src)
						.find("param[name='movie']").attr("src", src);
					$("#linklog .body").prepend(yt);
					uniqueImages[src] = true;
				}
			}
		}

		// put hyperlinks on the side:
		var links;
		if (links = body.match(REGEXES.urls.all_others)) {
			for (var i = 0, l = links.length; i < l; i++) {
				if (uniqueImages[links[i]] === undefined) {
					$("#linklog .body").prepend("<a href='" + links[i] + "' target='_blank'>" + links[i] + "</a>");
					uniqueImages[links[i]] = true;
				}
			}
		}

		// sanitize the body:
		body = body.replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;");

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
				chatMessageClasses += "me ";
			}

			var chat = chatMessageTemplate({
				nickname: msg.nickname,
				color: msg.color,
				body: body,
				humanTime: moment(msg.timestamp).format('hh:mm:ss'),
				timestamp: msg.timestamp,
				classes: chatMessageClasses,
				nickClasses: nickClasses
			});

			if (!opts.delayInsert) {
				insertChatMessage({
					timestamp: msg.timestamp,
					html: chat
				});
			}

			return chat;
		}
	};

	this.insertBatch = function (htmls) {
		$chatlog.append(htmls.join(""));
	};

	function insertChatMessage (opts) {
		// insert msg into the correct place in history
		var $chatMessage = $(opts.html);
		console.log(opts);
		if (opts.timestamp) {
			console.log("inserting !");
			var timestamps = _.map($("#chatarea .chatMessage .time"), function (ele) {
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
			var $target = $("#chatlog .chatMessage[rel='"+ candidate +"']");

			console.log(timestamps, candidate);

			if ($target.length) { // it was in the DOM, so we can insert the current message after it
				console.log('no target found');
				$target.after($chatMessage);
			} else { // it was the first message OR something went wrong
				console.log('something went wrong');
				$chatlog.append($chatMessage);
			}
		} else { // if there was no timestamp, assume it's a diagnostic message of some sort that should be displayed at the most recent spot in history
			console.log("not timestamp");
			$chatlog.append($chatMessage);
		}
		scroll();
	}

	this.renderUserlist = function (users) {
		if (users) { // if we have users
			// clear out the userlist
			$userlist.html("");
			
			_.each(users, function (user) {
				// add to our list of clients
				clients.add({
					client: user
				});
				// add him to the visual display
				var userHtml = userTemplate({
					nick: user.nick,
					cid: user.cID,
					color: user.color,
					identified: user.identified,
					idle: user.idle
				});
				$userlist.append(userHtml);
			});
		} else {
			// there's always gonna be someone...
		}
	};

	return this;
}

