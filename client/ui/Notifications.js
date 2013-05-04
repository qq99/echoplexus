// object: a wrapper around Chrome OS-level notifications
function UserNotifications () {
	"use strict";
	var hasPermission = 1,
		enabled = false,
		_notificationProvider = null;

	if (window.webkitNotifications) {
		_notificationProvider = window.webkitNotifications;
		hasPermission = _notificationProvider.checkPermission();
	} else if (window.Notifications) {
		_notificationProvider = window.Notifications;
		hasPermission = _notificationProvider.checkPermission();
	}
	function notify(user,body) {
		if (!enabled) return;

		if (document.hasFocus()) {

		} else {
			if (hasPermission === 0) { // allowed
				var notification = _notificationProvider.createNotification(
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
		if (_notificationProvider) {
			_notificationProvider.requestPermission();
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
