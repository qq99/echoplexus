# object: a wrapper around Chrome OS-level notifications
define ["underscore"], (_) ->
  ->
    # not granted nor denied

    # window.focus();
    # this.cancel();
    # this.close();
    # window.close();
    # :s

    # find out what we know about the domain's current notification state
    # shim for older webkit
    # Standards

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
    notify = (userOptions) ->
      return  unless enabled
      if not document.hasFocus() and _permission is "granted" and window.OPTIONS["show_OS_notifications"]
        title = undefined
        opts = _.clone(defaults)
        _.extend opts, userOptions
        title = opts.title
        delete opts.title

        if window.ua.node_webkit # Application
          if process.platform is "linux"
            _growl opts.body,
              image: process.cwd() + "/echoplexus-logo.png"

        else if window.webkitNotifications # shim for old webkit
          notification = _notificationProvider.createNotification(opts.iconUrl, title, opts.body)
          # params: (icon [url], notification title, notification body)
          notification.show()
          setTimeout (->
            notification.cancel()
          ), opts.TTL
        else if window.Notification # Standards
          notification = new Notification(title, opts)
          setTimeout (->
            notification.cancel()
          ), opts.TTL

    #
    #		(Boolean) Are OS notification permissions granted?
    #
    hasPermission = ->
      _permission

    #
    #		Polyfill to request notification permission
    #
    requestNotificationPermission = ->
      if _permission is "default" # only request it if we don't have it
        if window.webkitNotifications
          window.webkitNotifications.requestPermission()
        else if window.Notification
          window.Notification.requestPermission (perm) ->
            _permission = perm

    "use strict"
    _permission = "default"
    enabled = false
    _growl = null
    _notificationProvider = null
    defaults =
      title: "Echoplexus"
      dir: "auto"
      icon: window.location.origin + "/echoplexus-logo.png"
      iconUrl: window.location.origin + "/echoplexus-logo.png"
      lang: ""
      body: ""
      tag: ""
      TTL: 5000
      onshow: ->
        setTimeout (->
        ), 5000

      onclose: ->

      onerror: ->

      onclick: ->

    if window.webkitNotifications
      _notificationProvider = window.webkitNotifications
      hasPermission = _notificationProvider.checkPermission()
      if hasPermission is 0
        _permission = "granted"
      else
        _permission = "denied"
    else _permission = window.Notification.permission  if window.Notification.permission  if window.Notification
    if window.ua.node_webkit
      _permission = "granted"
      _growl = window.requireNode("growl")
    notify: notify
    enable: ->
      enabled = true

    hasPermission: hasPermission
    request: requestNotificationPermission
