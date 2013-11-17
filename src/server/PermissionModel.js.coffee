((exports) ->
  _ = require("underscore")
  PermissionModel = require("../client/PermissionModel.js").PermissionModel
  exports.ClientPermissionModel = PermissionModel.extend(
    initialize: ->
      self = this
      _.bindAll this
      PermissionModel::initialize.apply this, arguments_

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
  )
  exports.ChannelPermissionModel = PermissionModel.extend(defaults:
    canSetTopic: null # null represents no particular privilege or inhibition
    canMakePrivate: null
    canMakePublic: null
    canKick: null
    canMute: null
    canBan: null
    canSpeak: true
    canPullLogs: true
    canUploadFile: false
  )
) (if typeof exports is "object" then exports else this)
