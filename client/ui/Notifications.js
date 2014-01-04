// object: a wrapper around Chrome OS-level notifications
define(['underscore'],function(_){

	return function() {
		"use strict";
		var _permission = "default", // not granted nor denied
			enabled = false,
			_growl = null,
			_notificationProvider = null,
			defaults = {
				title: "Echoplexus",
				dir: "auto",
				icon: window.location.origin + "/echoplexus-logo.png",
				iconUrl: window.location.origin + "/echoplexus-logo.png",
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
		if (window.webkitNotifications) { // shim for older webkit
			_notificationProvider = window.webkitNotifications;
			hasPermission = _notificationProvider.checkPermission();
			if (hasPermission === 0) {
				_permission = "granted";
			} else {
				_permission = "denied";
			}
		} else if (window.Notification) { // Standards
			if (window.Notification.permission) {
				_permission = window.Notification.permission;
			}
		} 

		if (window.ua.node_webkit) {
			_permission = "granted";
			_growl = window.requireNode('growl');
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

			if (!document.hasFocus() &&
				_permission === "granted" &&
				window.OPTIONS["show_OS_notifications"]) {
				
				var title,
					opts = _.clone(defaults);

				_.extend(opts, userOptions);

				title = opts.title;
				delete opts.title;

				if (window.ua.node_webkit) { // Application
					if (process.platform === 'linux') {
						_growl(opts.body, {
							image: process.cwd() + '/echoplexus-logo.png'
						});
					}
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
				} else if (window.Notification) { // Standards
					var notification = new Notification(title, opts);

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
				if (window.webkitNotifications) {
					window.webkitNotifications.requestPermission();	
				} else if (window.Notification) {
					window.Notification.requestPermission(function (perm) {
						_permission = perm;
					});
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
});