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
				canSetTopic: true,
				canMakePrivate: true,
				canMakePublic: true,
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