(function( exports ) {

	var _ = require('underscore'),
		PermissionModel = require('../client/PermissionModel.js').PermissionModel;

	exports.ClientPermissionModel = PermissionModel.extend({
		initialize: function () {
			var self = this;

			_.bindAll(this);

			PermissionModel.prototype.initialize.apply(this, arguments);
		},
		upgradeToOperator: function () {
			this.set({
				canSetTopic: true,
				canMakePrivate: true,
				canMakePublic: true,
				canKick: true,
				canMute: true,
				canBan: true,
				canSpeak: true,
				canPullLogs: true
			});
			this.canBestow = this.attributes;
		}
	});

	exports.ChannelPermissionModel = PermissionModel.extend({
		defaults: {
			canSetTopic: null, // null represents no particular privilege or inhibition
			canMakePrivate: null,
			canMakePublic: null,
			canKick: null,
			canMute: null,
			canBan: null,
			canSpeak: true,
			canPullLogs: true
		}
	});

})(
  typeof exports === 'object' ? exports : this
);