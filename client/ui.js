$(document).ready(function () {

	var LOG_VERSION = "0.0.1";
	var transitionEvents = "webkitTransitionEnd transitionend oTransitionEnd";

	$("body").on("mouseenter", ".tooltip-target", function(ev) {
		var title = $(this).data("tooltip-title");
		var body = $(this).data("tooltip-body");
		var tclass = $(this).data("tooltip-class");

		var $tooltip = $(tooltipTemplate);
		var $target = $(ev.target);
		if (!$target.hasClass("tooltip-target")) { // search up to find the true tooltip target
			$target = $target.parents(".tooltip-target");
		}
		var targetOffset = $target.offset();
		$tooltip.css({
			left: targetOffset.left + ($target.width()/2),
			top: targetOffset.top + ($target.height())
		}).addClass(tclass)
			.find(".title").text(title)
		.end()
			.find(".body").text(body);

		$("body").append($tooltip);

		setTimeout(function () {
			$tooltip.addClass("showing");
		},10);
	}).on("mouseleave", ".tooltip-target", function (ev) {
		$("body .tooltip").removeClass("showing");
	});

	$("body").on(transitionEvents, ".tooltip", function () {
		if (!$(this).hasClass("showing")) {
			$(this).remove();
		}
	});

	// consider these persistent options
	// we use a cookie for these since they're small and more compatible
	var options = {
		"autoload_media": true,
		"suppress_join": false,
		"highlight_mine": true
	};

	function updateOption (option) {
		// update the options hash based upon the cookie
		var $option = $("#" + option);
		if ($.cookie(option) !== null) {
			if ($.cookie(option) === "false") {
				$option.removeAttr("checked");
				options[option] = false;
			} else {
				$option.attr("checked", "checked");
				options[option] = true;
			}

			if (options[option]) {
				$("body").addClass(option);
			} else {
				$("body").removeClass(option);
			}
		}
		// bind events to the click of the element of the same ID as the option's key
		$option.on("click", function () {
			$.cookie(option, $(this).prop("checked"));
			options[option] = !options[option];
			if (options[option]) {
				$("body").addClass(option);
			} else {
				$("body").removeClass(option);
			}
			scrollChat();
		});
	}

	_.each(_.keys(options), updateOption); // update all options we know about


	// ghetto templates:
	var clients = new Clients();
	var tooltipTemplate = $("#tooltip").html();
	var identYesTemplate = $("#identYes").html();
	var identNoTemplate = $("#identNo").html();
	var imageContainer = $("#imageThumbnail").html();
	var messageContainer = $("#chatMessage").html();
	var fl_obj_template = '<object>' +
                  '<param name="movie" value=""></param>' +   
                  '<param name="allowFullScreen" value="true"></param>' +   
                  '<param name="allowscriptaccess" value="always"></param>' +   
                  '<embed src="" type="application/x-shockwave-flash" allowscriptaccess="always" allowfullscreen="true" width="274" height="200"></embed>' +   
                  '</object>'; 

	// utility: extend the local storage protoype if it exists
	if (window.Storage) {
		Storage.prototype.setObj = function(key, obj) {
			return this.setItem(key, JSON.stringify(obj));
		};
		Storage.prototype.getObj = function(key) {
			return JSON.parse(this.getItem(key));
		};
	}

	// object: a persistent log if local storage is available ELSE noops
	function Log() {
		var latestID = -Infinity,
			log = [], // should always be sorted by timestamp
			logMax = 512;



		if (window.Storage) {
			var version = window.localStorage.getItem("logVersion");
			if (typeof version === "undefined" || version === null || version !== LOG_VERSION) {
				window.localStorage.setObj("log", null);
				window.localStorage.setItem("logVersion", LOG_VERSION);
			}
			var prevLog = window.localStorage.getObj("log");
			
			if (log.length > logMax) { // kill the previous log, getting too big; TODO: make this smarter
				window.localStorage.setObj("log", null);
			} else if (prevLog) {
				log = prevLog;
			}

			return {
				add: function (obj) {
					if (obj.log === false) return; // don't store things we're explicitly ordered not to
					if (obj.timestamp === false) return; // don't store things without a timestamp

					if (obj.ID && obj.ID > latestID) { // keep track of highest so far
						latestID = obj.ID;
					}

					// insert into the log
					log.push(obj);

					// sort the log for consistency:
					log = _.sortBy(log, "timestamp");

					// cull the older log entries
					if (log.length > logMax) {
						log.unshift();
					}

					// presist to localStorage:
					window.localStorage.setObj("log", log);
				},
				empty: function () {
					return (log.length === 0);
				},
				all: function () {
					return log;
				},
				latestID: function () {
					return smallestSeenMessageID;
				},
				latestIs: function (id) {
					id = parseInt(id, 10);
					if (id > latestID) {
						latestID = id;
					}
				},
				getMissingIDs: function (N) {
					// compile a list of the message IDs we know about
					var known = _.without(_.map(log, function (obj) {
						return obj.ID;
					}), undefined);
					// if we don't know about the server-sent latest ID, add it to the list:
					if (known[known.length-1] !== latestID) {
						known.push(latestID);
					}
					known.unshift(-1); // a default element

					// console.log("we know:", known);

					// compile a list of message IDs we know nothing about:
					var holes = [];
					for (var i = known.length - 1; i > 0; i--) {
						var diff = known[i] - known[i-1];
						for (var j = 1; j < diff; j++) {
							holes.push(known[i] - j);
							if (N && (holes.length === N)) { // only get N holes if we were requested to limit ourselves
								console.log("we don't know:", holes);
								return holes;
							}
						}
					}
					// console.log("we don't know:", holes);
					return holes;
				}
			};
		} else { /// return a fake for those without localStorage
			return {
				add: function () {},
				empty: function () { return true; },
				all: function () {
					return log;
				}
			};
		}
	}

	// object: a wrapper around Chrome OS-level notifications
	function Notifications () {
		var hasPermission = 1,
			enabled = false;

		if (window.webkitNotifications) {
				hasPermission = window.webkitNotifications.checkPermission();
		}
		function notify(user,body) {
			if (!enabled) return;

			if (document.hasFocus()) {

			} else {
				if (hasPermission === 0) { // allowed
					var notification = window.webkitNotifications.createNotification(
						'http://i.stack.imgur.com/dmHl0.png',
						user + " says:",
						body
					);


					notification.show();
					setTimeout(function () {
						notification.cancel();
					}, 5000);
				} else { // not allowed
					// hmm
				}
			}
		}
		function requestNotificationPermission() {
			if (window.webkitNotifications) {
				window.webkitNotifications.requestPermission();
			}
		}

		return {
			notify: notify,
			enable: function () {
				enabled = true;
			},
			request: requestNotificationPermission
		};
	}

	// object: given a string A, returns a string B iff A is a substring of B
	//	transforms A,B -> lowerCase for the comparison
	//		TODO: use a scheme involving something like l-distance instead
	function Autocomplete () {
		var pool = [],
			cur = 0,
			lastStub,
			candidates;

		return {
			setPool: function (arr) {
				pool = arr;
				candidates = [];
				lastStub = null;
			},
			next: function (stub) {
				if (!pool.length) return "";

				stub = stub.toLowerCase(); // transform the stub -> lcase
				if (stub !== lastStub) { // update memoized candidates
					candidates = pool.filter(function (element, index, array) {
						return (element.toLowerCase().indexOf(stub) !== -1);
					});
				}

				if (!candidates.length) return "";

				cur += 1;
				cur = cur % candidates.length;
				name = candidates[cur];
				
				return name;
			}
		};
	}

	// object: a stack-like data structure supporting only:
	//	- an index representing the currently looked-at element
	//	- adding new elements to the top of the stack
	//	- emptying the stack
	function Scrollback () {
		var buffer = [],
			position = 0;
		
		return {
			add: function (userInput) {
				buffer.push(userInput);
				position += 1;
			},
			prev: function () {
				if (position > 0) {
					position -= 1;
				}
				return buffer[position];
			},
			next: function () {
				if (position < buffer.length) {
					position += 1;
				}
				return buffer[position];
			},
			reset: function () {
				position = buffer.length;
			}
		};
	}

	var scrollback = new Scrollback();
	var autocomplete = new Autocomplete();
	var notifications = new Notifications();
	var log = new Log();
	var uniqueImages = {};

	function handleChatMessage(msg) {

		if (!msg.body) return; // if there's no body, we probably don't want to do anything
		var body = msg.body;
		if (body.match(REGEXES.commands.nick)) {
			body = body.replace(REGEXES.commands.nick, "").trim();
			session.setNick(body);
			return;
		} else if (msg.body.match(REGEXES.commands.register)) {
			msg.body = msg.body.replace(REGEXES.commands.register, "").trim();
			socket.emit('register_nick', {
				password: msg.body
			});
			return;
		} else if (msg.body.match(REGEXES.commands.identify)) {
			msg.body = msg.body.replace(REGEXES.commands.identify, "").trim();
			socket.emit('identify', {
				password: msg.body
			});
			return;
		} else if (msg.body.match(REGEXES.commands.topic)) {
			msg.body = msg.body.replace(REGEXES.commands.topic, "").trim();
			socket.emit('topic', {
				topic: msg.body
			});
			return;
		} else if (msg.body.match(REGEXES.commands.failed_command)) {
			return;
		} else {
			session.speak(msg);
		}
	}

	function makeYoutubeURL(s) {
		var start = s.indexOf("v=") + 2;
		var end = s.indexOf("&", start);
		if (end === -1) {
			end = s.length;
		}
		return "http://youtube.com/v/" + s.substring(start,end);
	}

	function scrollChat() {
		$("#chatlog .messages").scrollTop($("#chatlog .messages")[0].scrollHeight);
	}

	function renderChatMessage(msg) {
		var body = msg.body;
		// console.log(msg.cID, session.id());

		// put image links on the side:
		var images;
		if (options["autoload_media"] && (images = body.match(REGEXES.urls.image))) {
			for (var i = 0, l = images.length; i < l; i++) {
				var href = images[i],
					img = $(imageContainer);

				if (uniqueImages[href] === undefined) {
					img.find("a").attr("href", href)
								  .attr("title", "Linked by " + msg.nickname)
						.find("img").attr("src", href);
					$("#linklog .body").prepend(img);
					uniqueImages[href] = true;
				}
			}

			body = body.replace(REGEXES.urls.image, "").trim(); // remove the URLs
		}

		// put youtube linsk on the side:
		var youtubes;
		if (options["autoload_media"] && (youtubes = body.match(REGEXES.urls.youtube))) {
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
			var chat = $(messageContainer);
			chat.find(".nick").text(msg.nickname).attr("title", msg.nickname);
			chat.find(".body").html(body);
			chat.find(".time").text("[" + moment(msg.timestamp).format('hh:mm:ss') + "]");
			chat.attr("data-timestamp", msg.timestamp);

			if (msg.color) {
				chat.find(".nick").css("color", msg.color);
			}

			// special styling of nickname depending on who you are:
			if (msg.type === "SYSTEM") {
				chat.find(".nick").addClass("system");
			}
			if (msg.you) { // if it's me!
				chat.find(".nick").addClass('me');
				chat.addClass('me');
			}

			if (msg.class) {
				chat.addClass(msg.class);
			}

			// insert msg into the correct place in history
			if (msg.timestamp) {

				var timestamps = _.map($("#chatarea .chatMessage"), function (ele) {
					return $(ele).data("timestamp");
				});

				var cur = msg.timestamp,
					candidate = -1;
				
				chat.attr("rel", cur);
				// find the earliest message we know of that's before the message we're about to render
				for (var i = timestamps.length - 1; i >= 0; i--) {
					candidate = timestamps[i];
					if (cur > timestamps[i]) break;
				}
				// attempt to select this early message:
				var $target = $("#chatlog .chatMessage[rel='"+ candidate +"']");

				if ($target.length) { // it was in the DOM, so we can insert the current message after it
					$target.after(chat);
				} else { // it was the first message OR something went wrong
					$("#chatlog .messages").append(chat);
				}
			} else { // if there was no timestamp, assume it's a diagnostic message of some sort that should be displayed at the most recent spot in history
				$("#chatlog .messages").append(chat);
			}
			scrollChat();
		}

		// scan through the message and determine if we need to notify somebody that was mentioned:
		if (body.toLowerCase().split(" ").indexOf(session.getNick().toLowerCase()) !== -1) {
			notifications.notify(msg.nickname, body.substring(0,50));
			chat.addClass("highlight");
		}
	}

	var editors = [];
	var jsEditor = CodeMirror.fromTextArea(document.getElementById("codeEditor"), {
		lineNumbers: true,
		mode: "text/javascript",
		theme: "monokai",
		matchBrackets: true,
		highlightActiveLine: true,
		continueComments: "Enter"
	});
	var htmlEditor = CodeMirror.fromTextArea(document.getElementById("htmlEditor"), {
		lineNumbers: true,
		mode: "text/html",
		theme: "monokai"
	});

	editors.push({
		namespace: "js",
		editor: jsEditor
	}, {
		namespace: "html",
		editor: htmlEditor
	});

	var socket = io.connect(window.location.href);
	socket.on('connect', function () {
		session = new Client({ 
			socketRef: socket,
		});

		// if there's something in the persistent chatlog, render it:
		if (!log.empty()) {
			var entries = log.all();
			for (var i = 0, l = entries.length; i < l; i++) {
				renderChatMessage(entries[i]);
			}
		}
		$("#chatarea .chatMessage").addClass("fromlog");


		notifications.enable();


		socket.on('chat', function (msg) {
			switch (msg.class) {
				case "join":
					clients.add({
						client: msg.client
					});
					break;
				case "part":
					clients.kill(msg.clientID);
					break;
			}

			log.add(msg);
			renderChatMessage(msg);
			scrollChat();
		});


		socket.on('userlist', function (msg) {
			// console.log(msg);
			if (msg.you) {
				session.setID(msg.you);
			}
			if (msg.users && msg.users.length) {
				_.each(msg.users, function (user) {
					clients.add({
						client: user
					});
				});
				// console.log(clients.userlist());
				autocomplete.setPool(_.map(msg.users, function (user) {
					return user.nick;
				}));
				$("#userlist .body").html("");
				for (var i = 0, l = msg.users.length; i < l; i++) {
					var user = $("<div class='user'></div>").text(msg.users[i].	nick);
					user.css("color", msg.users[i].color);

					if (msg.users[i].identified) {
						user.append(identYesTemplate);
					} else {
						user.append(identNoTemplate);
					}
					
					$("#userlist .body").append(user);
				}
			}
		});

		function applyChanges (editor, change) {
			editor.replaceRange(change.text, change.from, change.to);
			while (change.next !== undefined) { // apply all the changes we receive until there are no more
				change = change.next;
				editor.replaceRange(change.text, change.from, change.to);
			}
		}

		_.each(editors, function (obj) {
			var editor = obj.editor;
			var namespace = obj.namespace.toString();

			socket.on(namespace + ":code:change", function (change) {
				applyChanges(editor, change);
			});

			socket.on(namespace + ":code:request", function () {
				socket.emit("code:full_transcript", {
					code: editor.getValue()
				});
			});
			socket.on(namespace + ":code:sync", function (data) {
				if (editor.getValue() !== data.code) {
					editor.setValue(data.code);
				}
			});

			socket.on(namespace + ":code:authoritative_push", function (data) {
				editor.setValue(data.start);
				for (var i = 0; i < data.ops.length; i ++) {
					applyChanges(editor, data.ops[i]);
				}
			});

			socket.on(namespace + ":code:cursorActivity", function (data) {
				var pos = editor.charCoords(data.cursor);
				var $ghostCursor = $(".ghost-cursor[rel='" + data.id + "']");
				if (!$ghostCursor.length) {
					$ghostCursor = ("<div class='ghost-cursor' rel=" + data.id +"></div>");
					$("body").append($ghostCursor);
				}
				$ghostCursor.css({
					background: clients.get(data.id).getColor().toRGB(),
					top: pos.top,
					left: pos.left
				});
			});
		});

		if ($.cookie("nickname")) {
			session.setNick($.cookie("nickname"));
		}


		$("#chatinput textarea").on("keydown", function (ev) {
			$this = $(this);
			switch (ev.keyCode) {
				// enter:
				case 13:
					ev.preventDefault();
					var userInput = $this.val();
					scrollback.add(userInput);
					// userInput = userInput.split("\n");
					// for (var i = 0, l = userInput.length; i < l; i++) {
					// 	handleChatMessage({
					// 		body: userInput[i]
					// 	});
					// }
					handleChatMessage({
						body: userInput
					});
					$this.val("");
					scrollback.reset();
					break;
				// up:
				case 38:
					$this.val(scrollback.prev());
					break;
				// down
				case 40:
					$this.val(scrollback.next());
					break;
				// escape
				case 27:
					scrollback.reset();
					$this.val("");
					break;
				// L
				case 76:
					if (ev.ctrlKey) {
						ev.preventDefault();
						$("#chatlog .messages").html("");
						$("#linklog .body").html("");
					}
					break;
				 // tab key
				case 9:
					ev.preventDefault();
					var text = $(this).val().split(" ");
					var stub = text[text.length - 1];				
					var completion = autocomplete.next(stub);

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
	});

	socket.on('chat:currentID', function (data) {
		log.latestIs(data.ID);
	});

	socket.on('disconnect', function () {
		setTimeout(function () { // for dev, cheap auto-reload
			window.location = window.location;
		}, 2000);
		socket.removeAllListeners();
		socket.removeAllListeners('chat'); 
		socket.removeAllListeners('userlist');
		socket.removeAllListeners('code:change code:authoritative_push code:sync code:request');
		$("#chatinput textarea").off();
		renderChatMessage({body: "Unexpected d/c from server", log: false});
	});

	$("#chatlog").on("hover", ".chatMessage", function (ev) {
		$(this).attr("title", "sent " + moment($(this).data("timestamp")).fromNow());
	});

	$("span.options").on("click", function (ev) {
		$(this).siblings("div.options").toggle();
	});

	$("#chatinput textarea").focus();

	$(window).on("click", function () {
		notifications.request();
	});



	$("#codeButton").on("click", function (ev) {
		ev.preventDefault();
		if ($("#coding:visible").length === 0) {
			$("#chatting").fadeOut();
			$("#coding").fadeIn(function () {
				_.each(editors, function (obj) {
					obj.editor.refresh();
				});
				$(".ghost-cursor").show();
			});
		}
	});

	$("#chatButton").on("click", function (ev) {
		ev.preventDefault();
		if ($("#chatting:visible").length === 0) {
			$("#coding").fadeOut();
			$("#chatting").fadeIn(function () {
				scrollChat();
				$(".ghost-cursor").hide();
			});
		}
	});

	$("#syncButton").on("click", function (ev) {
		var missed = log.getMissingIDs(10);
		if (missed.length) {
			socket.emit("chat:history_request", {
				requestRange: missed
			});
		}
	});

	$("#deleteLocalStorage").on('click', function (ev) {
		ev.preventDefault();
		window.localStorage.setObj("log", null);
	});



	$(window).on("blur", function () {
		$("body").addClass("blurred");
	}).on("focus", function () {
		$("body").removeClass("blurred");
	});

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
	

	var iframe = document.getElementById("repl-frame").contentWindow;

	var updateJsEval = _.debounce(function () {
		values = {};
		_.each(editors, function (obj) {
			values[obj.namespace] = obj.editor.getValue();
		});
		var html = values["html"];
		var script = values["js"];
		var wrapped_script = "(function(){ "; // execute in a closure
		wrapped_script+= "return (function(window,$,_,alert,undefined) {" // don't allow user to override things
		wrapped_script+= script;
		wrapped_script+= "})(window,$,_, function () { return arguments; });"
		wrapped_script +="})();";

		// first update the iframe from the HTML:
		var iframe = document.getElementById("repl-frame").contentDocument
		iframe.open();
		iframe.write(html);
		iframe.close();
		// then execute the JS:
		if (script !== "") {
			var result;
			try {
				result = document.getElementById("repl-frame").contentWindow.eval(wrapped_script);
				if (_.isObject(result)) {
					result = JSON.stringify(result);
				} 
				else if (result === undefined) {
					result = "undefined";
				}
				else {
					result = result.toString();
				}
			} catch (e) {
				result = e.toString();
			}
			$("#result_pane .output").text(result);
		} else {
			$("#result_pane .output").text("");
		}
	}, 500);

});