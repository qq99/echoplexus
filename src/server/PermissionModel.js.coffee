_                 = require("underscore")
PermissionModel   = require("../client/PermissionModel.coffee").PermissionModel

module.exports.ClientPermissionModel = class ClientPermissionModel extends PermissionModel
  initialize: ->
    _.bindAll this
    super

  upgradeToOperator: ->
    @set
      canSetTopic: true
      canMakePrivate: true
      canMakePublic: true
      canKick: true
      canMute: true
      canBan: true
      canSpeak: true
      canPullLogs: true
      canUploadFile: true

    @canBestow = @attributes

module.exports.ChannelPermissionModel = class ChannelPermissionModel extends PermissionModel

  defaults:
    canSetTopic: null # null represents no particular privilege or inhibition
    canMakePrivate: null
    canMakePublic: null
    canKick: null
    canMute: null
    canBan: null
    canSpeak: true
    canPullLogs: true
    canUploadFile: false
