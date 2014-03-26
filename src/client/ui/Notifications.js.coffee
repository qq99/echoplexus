# object: a wrapper around Chrome OS-level notifications
module.exports.Notifications = class Notifications

    _permission = "default"
    _growl = null

    defaults:
      title: "echoplexus"
      dir: "auto"
      icon: window.location.origin + "/echoplexus-logo.png"
      iconUrl: window.location.origin + "/echoplexus-logo.png"
      lang: ""
      body: ""
      tag: ""
      TTL: 5000
      onshow: ->
      onclose: ->
      onerror: ->
      onclick: ->

    constructor: ->
      _permission = window.Notification?.permission

      if window.ua?.node_webkit?
        _permission = "granted"
        _growl = window.requireNode("growl")

    #
    #		Polyfill to present an OS-level notification:
    #		options: {
    #			title: "Displays at the top",
    #			dir: "auto", // text direction
    #			lang: "",
    #			body: "The text you want to display",
    #			tag: "the class of notifications it's in",
    #			TTL: (milliseconds) amount of time to keep it alive
    #		}
    #
    notify: (userOptions, focusOverride = false) ->
      if !focusOverride
        if document.hasFocus()
          console.log "Document is focused, so notifications are suppressed"
          return
      if !OPTIONS["show_OS_notifications"]
        console.log "Suppressing client notification due to client preference"
        return
      if _permission != "granted"
        console.log "Unable to display notification: user has not granted permission to do so"
        return

      opts = _.clone(@defaults)
      _.extend opts, userOptions
      title = opts.title || ""
      delete opts.title

      if window.ua.node_webkit # Application
        if process.platform is "linux"
          _growl opts.body,
            image: process.cwd() + "/echoplexus-logo.png"
      else if window.Notification # Standards
        notification = new Notification(title, opts)
        setTimeout (->
          notification.close()
        ), opts.TTL
      # else # screw the other webkitNotifications mozNotifications and others

    #
    #		(Boolean) Are OS notification permissions granted?
    #
    hasPermission: ->
      _permission

    #
    #		Polyfill to request notification permission
    #
    requestNotificationPermission: ->
      if _permission is "default" # only request it if we don't have it
        if window.Notification
          window.Notification.requestPermission (perm) ->
            _permission = perm

    request: @requestNotificationPermission
