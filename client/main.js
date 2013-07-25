if (typeof DEBUG === 'undefined') DEBUG = true; // will be removed


function codingModeActive () { // sloppy, forgive me
	return $("#coding").is(":visible");
}
function chatModeActive () {
	return $("#chatting").is(":visible");
}

//We need the require function for loading variadic modules
define(function(require,exports,module){
	//Set cookie options
	// 14 seems like a good time to keep the cookie around
	window.COOKIE_OPTIONS = {
		path: '/',
		expires: 14
	};
	// require secure cookies if the protocol is https
	if (window.location.protocol === "https:") {
		window.COOKIE_OPTIONS.secure = true;
	}
	var $ = require('jquery'),
		_ = require('underscore'),
		key = require('keymaster'),
		ChannelSwitcher = require('ui/ChannelSwitcher'),
		Notifications = require('ui/Notifications'),
		faviconizer = require('ui/Faviconizer');

	require('jquery.cookie');
	require('events');
	require('utility');

	$(document).ready(function () {
		// tooltip stuff:s
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

			this.tooltip_timer = setTimeout(function () {
				$("body").append($tooltip);
				$tooltip.fadeIn();
			},350);
		}).on("mouseleave", ".tooltip-target", function (ev) {
			clearTimeout(this.tooltip_timer);
			$("body .tooltip").fadeOut(function () {
				$(this).remove();
			});
		});

		// consider these persistent options
		// we use a cookie for these since they're small and more compatible
		window.OPTIONS = {
			"show_growl": true,
			"suppress_join": false,
			"highlight_mine": true,
			"prefer_24hr_clock": true,
			"suppress_client": false,
			"suppress_identity_acknowledgements": false,
			"auto_scroll": true //autoscroll to new chat messages
		};

		function updateOption (value, option) {
			var $option = $("#" + option);
			//Check if the options are in the cookie, if so update the value
			if (typeof $.cookie(option) !== "undefined") value = !($.cookie(option) === "false");
			window.OPTIONS[option] = value;
			if (value) {
				$("body").addClass(option);
				$option.attr("checked", "checked");
			} else {
				$("body").removeClass(option);
				$option.removeAttr("checked");
			}
			// bind events to the click of the element of the same ID as the option's key
			$option.on("click", function () {
				$.cookie(option, $(this).prop("checked"), window.COOKIE_OPTIONS);
				OPTIONS[option] = !OPTIONS[option];
				if (OPTIONS[option]) {
					$("body").addClass(option);
				} else {
					$("body").removeClass(option);
				}
				// chat.scroll();
			});
		}

		_.each(window.OPTIONS, updateOption); // update all options we know about

		$(".options-list .header button, .options-list .header .button").on("click", function () {
			var panel = $(this).parent().siblings(".options");
			if (panel.is(":visible")) {
				panel.slideUp();
			} else {
				panel.slideDown();
			}
		});


		// ghetto templates:
		var tooltipTemplate = $("#tooltip").html();

		window.notifications = new Notifications();
		$(window).on("blur", function () {
			$("body").addClass("blurred");
		}).on("focus mouseenter", function () {
			$("body").removeClass("blurred");
			document.title = "echoplexus";

			if (typeof window.disconnected === "undefined" ||
				!window.disconnected) {

				faviconizer.setConnected();
			}
		});

		io.connect(window.location.origin,{
			'connect timeout': 1000,
			'reconnect': true,
			'reconnection delay': 2000,
			'max reconnection attempts': 1000
		});

		var channelSwitcher = new ChannelSwitcher();
		$("header").append(channelSwitcher.$el);

		// socket.on('connect', function () {

		notifications.enable();

		$("span.options").on("click", function (ev) {
			$(this).siblings("div.options").toggle();
		});

		$(window).on("click", function () {
			notifications.request();
		});

		// messy, hacky, but make it safer for now
		function turnOffLiveReload () {
			$(".livereload").attr("checked", false);
		}


		// hook up global key shortcuts:
		key.filter = function () { return true; }; // stub out the filter method from the lib to enable them globally

		// change channels:
		key('alt+right, alt+k', function () {
			channelSwitcher.trigger("nextChannel");
			return false;
		});
		key('alt+left, alt+j', function () {
			channelSwitcher.trigger("previousChannel");
			return false;
		});
		key('ctrl+shift+c', function () {
			channelSwitcher.trigger("leaveChannel");
			return false;
		});
		// quick reply to PM:
		key('ctrl+r', function () {
			var replyTo = $(".chatlog:visible .chatMessage.private:not(.me)").last().find(".nick").text().trim(),
				$chatInput = $(".chatinput:visible textarea"),
				currentBuffer;


			currentBuffer = $chatInput.val();
			if (replyTo !== "" &&
				currentBuffer.indexOf("/w " + replyTo) === -1) {
				// prepend the command and the user string
				$chatInput.val("/w " + replyTo + " " + currentBuffer);
			}

			return false; // don't trigger browser's autoreload
		});

		// change tabs:
		var tabs = $('#buttons').children();
		var activeTabIndex = $('#buttons .active').index();
		key('alt+shift+right, alt+shift+k, alt+shift+d', function () {
			activeTabIndex += 1;
			activeTabIndex = activeTabIndex % tabs.length; // prevent array OOB
			$(tabs[activeTabIndex]).trigger("click");
			return false; // don't trigger alt+right => "History Forward"
		});
		key('alt+shift+left, alt+shift+j, alt+shift+s', function () {
			activeTabIndex -= 1;
			if (activeTabIndex < 0) { // prevent array OOB
				activeTabIndex = tabs.length - 1;
			}
			$(tabs[activeTabIndex]).trigger("click");
			return false; // don't trigger alt+left => "History Back"
		});
		$('.tabButton').on('click',function(ev){
			ev.preventDefault();
			console.log('changing tab');
			$(this).removeClass("activity");
			var element = $(this).data('target');
			if ($(element + ":visible").length === 0) {
				$(this).addClass("active").siblings().removeClass("active");
				$("#panes > section").not(element).hide();
				$(element).show(function () {
					window.events.trigger("sectionActive:" + element.substring(1)); // sloppy, forgive me
				});
			}
		});

		window.events.on("chat:activity", function (data) {
			if (!chatModeActive()) {
				$(".button[data-target='#chatting']").addClass("activity");
			}
			if (!document.hasFocus()) {
				faviconizer.setActivity();
				document.title = "!echoplexus";
			}
		});

		// fire an event that signals we're no longer idle
		$(window).on("keydown mousemove", function () {
			window.events.trigger("unidle");
		});


		/*
		$("#drawButton").on("click", function (ev) {
			ev.preventDefault();
			$(this).removeClass("activity");
			if ($("#drawing:visible").length === 0) {
				$(this).addClass("active").siblings().removeClass("active");
				$("#panes > section").not('#drawing').hide();
				$("#drawing").show();
				$(".ghost-cursor").remove();
				turnOffLiveReload();
			}
		});*/

	});
});