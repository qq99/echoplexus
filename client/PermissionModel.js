(function(root, factory) {
	// Set up Backbone appropriately for the environment.
	if (typeof exports !== 'undefined') {
		// Node/CommonJS, no need for jQuery in that case.
		factory(
			exports,
			require('backbone'),
			require('underscore'),
			require('../server/config.js').Configuration
		);
	} else if (typeof define === 'function' && define.amd) {
		// AMD
		define(['backbone','underscore','exports'],
			function(Backbone, _, exports) {
				// Export global even in AMD case in case this script is loaded with
				// others that may still expect a global Backbone.
				return factory(exports, Backbone, _);
			}
		);
	}
})(this, function(exports, Backbone, _, config) {

	exports.PermissionModel = Backbone.Model.extend({
		defaults: {
			canSetTopic: null, // null represents no particular privilege or inhibition
			canMakePrivate: null,
			canMakePublic: null,
			canKick: null,
			canMute: null,
			canBan: null,
			canSpeak: null,
			canPullLogs: null
		},
		canBestow: null, // eventually a map of bestowable permissions
		initialize: function (modelAttributes, options) {
			_.bindAll(this);
		}
	});

});