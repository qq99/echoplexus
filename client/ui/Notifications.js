// object: a wrapper around Chrome OS-level notifications
function Notifications () {
	"use strict";
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
