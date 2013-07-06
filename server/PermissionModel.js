(function( exports ) {

	var _ = require('underscore'),
		PermissionModel = require('../client/PermissionModel.js').PermissionModel;

	exports.ServerPermissionModel = PermissionModel.extend({
		initialize: function () {
			var self = this;

			_.bindAll(this);

			PermissionModel.prototype.initialize.apply(this, arguments);
		},
		upgradeToOperator: function () {
			this.set({
				canTopic: true,
				canPrivate: true,
				canPublic: true,
				canKick: true,
				canMute: true,
				canBan: true
			});
			this.canBestow = this.attributes;
		}
	});

})(
  typeof exports === 'object' ? exports : this
);