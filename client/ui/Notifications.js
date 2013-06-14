// object: a wrapper around Chrome OS-level notifications
function UserNotifications () {
	"use strict";
	var _permission = "default", // not granted nor denied
		enabled = false,
		_notificationProvider = null,
		defaults = {
			title: "Echoplexus",
			dir: "auto",
			iconUrl: "",
			lang: "",
			body: "",
			tag: "",			
			TTL: 5000,
			onshow: function() {
				setTimeout(function () {
					// window.focus();
					// this.cancel();
					// this.close();
					// window.close();
					// :s
				}, 5000); 
			},
			onclose: function () {},
			onerror: function () {},
			onclick: function () {}
		};

	// find out what we know about the domain's current notification state
	if (window.Notification) { // Standards
		if (window.Notification.permission) {
			_permission = window.Notification.permission;
		}
	} else if (window.webkitNotifications) { // shim for older webkit
		hasPermission = _notificationProvider.checkPermission();
		if (hasPermission === 0) {
			_permission = "granted";
		} else {
			_permission = "denied";
		}
	}

	
	/*
	Polyfill to present an OS-level notification:
	options: {
		title: "Displays at the top",
		dir: "auto", // text direction
		lang: "",
		body: "The text you want to display",
		tag: "the class of notifications it's in",
		TTL: (milliseconds) amount of time to keep it alive
	}
	*/
	function notify(userOptions) {

		if (!enabled) return;

		if (!document.hasFocus() && _permission === "granted") {
			
			var title,
				opts = _.clone(defaults);

			_.extend(opts, userOptions);

			title = opts.title;
			delete opts.title;

			if (window.Notification) { // Standards
				var notification = new Notification(title, opts);

				// TODO: figure out how to close the notification :/
			} else if (window.webkitNotifications) { // shim for old webkit
				var notification = _notificationProvider.createNotification(
					opts.iconUrl,
					title,
					opts.body
				); // params: (icon [url], notification title, notification body)

				notification.show();
				setTimeout(function () {
					notification.cancel();
				}, opts.TTL);
			}
		}

	}

	/*
	(Boolean) Are OS notification permissions granted?
	*/
	function hasPermission() {
		return _permission;
	}
	/*
	Polyfill to request notification permission
	*/
	function requestNotificationPermission() {
		if (_permission === "default") { // only request it if we don't have it
			if (window.Notification) {
				window.Notification.requestPermission(function (perm) {
					_permission = perm;
				});
			} else {
				window.webkitNotifications.requestPermission();	
			}
		}
	}

	return {
		notify: notify,
		enable: function () {
			enabled = true;
		},
		hasPermission: hasPermission,
		request: requestNotificationPermission
	};
}
