$(document).ready(function () {
	

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
			$tooltip.fadeIn();
		},10);
	}).on("mouseleave", ".tooltip-target", function (ev) {
		$("body .tooltip").fadeOut();
	});

	$("body").on(transitionEvents, ".tooltip", function () {
		if (!$(this).hasClass("showing")) {
			$(this).remove();
		}
	});

	// consider these persistent options
	// we use a cookie for these since they're small and more compatible
	window.OPTIONS = {
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
				OPTIONS[option] = false;
			} else {
				$option.attr("checked", "checked");
				OPTIONS[option] = true;
			}

			if (OPTIONS[option]) {
				$("body").addClass(option);
			} else {
				$("body").removeClass(option);
			}
		}
		// bind events to the click of the element of the same ID as the option's key
		$option.on("click", function () {
			$.cookie(option, $(this).prop("checked"));
			OPTIONS[option] = !OPTIONS[option];
			if (OPTIONS[option]) {
				$("body").addClass(option);
			} else {
				$("body").removeClass(option);
			}
			chat.scroll();
		});
	}

	_.each(_.keys(OPTIONS), updateOption); // update all options we know about


	// ghetto templates:
	window.clients = new Clients();
	var tooltipTemplate = $("#tooltip").html();
	var identYesTemplate = $("#identYes").html();
	var identNoTemplate = $("#identNo").html();



	// utility: extend the local storage protoype if it exists
	if (window.Storage) {
		Storage.prototype.setObj = function(key, obj) {
			return this.setItem(key, JSON.stringify(obj));
		};
		Storage.prototype.getObj = function(key) {
			return JSON.parse(this.getItem(key));
		};
	}

	var chat = new Chat();
	window.scrollback = new Scrollback();
	window.autocomplete = new Autocomplete();
	window.notifications = new Notifications();
	window.log = new Log();
	window.uniqueImages = {};

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

	// if there's something in the persistent chatlog, render it:
	if (!log.empty()) {
		var entries = log.all();
		var renderedEntries = [];
		for (var i = 0, l = entries.length; i < l; i++) {
			renderedEntries.push(
				chat.renderChatMessage(entries[i], {
					delayInsert: true
				})
			);
		}
		chat.insertBatch(renderedEntries);
		$("#chatarea .chatMessage").addClass("fromlog");
		chat.scroll();
	}

	var socket = io.connect(window.location.href);
	socket.on('connect', function () {
		// socket.leave("");
		session = new Client({ 
			socketRef: socket
		});

		$(window).on("blur", function () {
			$("body").addClass("blurred");
		}).on("focus", function () {
			session.active();
			$("body").removeClass("blurred");
		});

		$(window).on("keydown mousemove", function () {
			session.active();
		});


		notifications.enable();

		session.active();

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

			// scan through the message and determine if we need to notify somebody that was mentioned:
			if (msg.body.toLowerCase().split(" ").indexOf(session.getNick().toLowerCase()) !== -1) {
				notifications.notify(msg.nickname, msg.body.substring(0,50));
				msg.directedAtMe = true;
			}

			log.add(msg);
			chat.renderChatMessage(msg);
			chat.scroll();
		});

		socket.on('chat:idle', function (msg) {
			$(".user[rel='"+ msg.cID +"']").append("<span class='idle'>Idle</span>");
			// console.log(session.id(), msg.cID);
			if (session.is(msg.cID)) {
				session.setIdle();
			}
		});
		socket.on('chat:unidle', function (msg) {
			// console.log(msg, $(".user[rel='"+ msg.cID +"'] .idle"), $(".user[rel='"+ msg.cID +"'] .idle").length);
			$(".user[rel='"+ msg.cID +"'] .idle").remove();
		});

		socket.on('chat:your_cid', function (msg) {
			session.setID(msg.cID);
		});


		socket.on('userlist', function (msg) {
			// update the pool of possible autocompletes
			autocomplete.setPool(_.map(msg.users, function (user) {
				return user.nick;
			}));

			chat.renderUserlist(msg.users);
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
					session.speak({
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
		chat.renderChatMessage({body: "Unexpected d/c from server", log: false});
	});

	$("#chatlog").on("hover", ".chatMessage", function (ev) {
		$(this).attr("title", "sent " + moment($(".time", this).data("timestamp")).fromNow());
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
				chat.scroll();
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