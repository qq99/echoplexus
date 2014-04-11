module.exports.PermissionModel = class PermissionModel extends Backbone.Model

  defaults:
    canSetTopic: null # null represents no particular privilege or inhibition
    canMakePrivate: null
    canMakePublic: null
    canKick: null
    canMute: null
    canBan: null
    canSpeak: null
    canPullLogs: null
    canUploadFile: null
    canDeleteLogs: null
    canSetGithubPostReceiveHooks: null

  canBestow: null # eventually a map of bestowable permissions
  initialize: (modelAttributes, options) ->

