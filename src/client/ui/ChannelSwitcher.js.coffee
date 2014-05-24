Client                    = require('../client.js.coffee')
ClientModel               = Client.ClientModel
ClientsCollection         = Client.ClientsCollection
Loader                    = require('../loader.js.coffee').Loader
buttonTemplate            = require('../templates/channelSelectorButton.html')

# Clients:
# abstract this to config.coffee
ChatClient                = require('../modules/chat/client.js.coffee').ChatClient
CodeClient                = require('../modules/code/client.js.coffee').CodeClient
DrawingClient             = require('../modules/draw/client.js.coffee').DrawingClient
CallClient                = require('../modules/call/client.js.coffee').CallClient
InfoClient                = require('../modules/info/client.js.coffee').InfoClient
utility                   = require("../utility.js.coffee")

module.exports.ChannelButton = class ChannelButton extends Backbone.View
  events:
    "click .close": "leaveChannel"
    "click button": "showChannel"

  initialize: (opts) ->
    _.bindAll.apply(_, [this].concat(_.functions(this)))
    @channelName = opts.channelName
    @data = new Backbone.Model
      topic: ""
      channelName: opts.channelName
      activeUsers: 1
      totalUsers: 1
    @render()

  leaveChannel: ->
    window.events.trigger("leaveChannel", @channelName)

  showChannel: ->
    window.events.trigger("showChannel", @channelName)

  setActive: ->
    @$el.find("button").addClass("active").removeClass("activity")

  setInactive: ->
    @$el.find("button").removeClass("active")

  destroy: ->
    @$el.remove()

  render: ->
    @$el.html(buttonTemplate())

    @stickit @data,
      ".j-channel-btn":
        attributes: [{
          name: 'data-channel'
          observe: 'channelName'
        }]
      ".channel-name": "channelName"
      ".active": "activeUsers"
      ".total": "totalUsers"
      ".topic": "topic"

module.exports.ChannelSwitcher = class ChannelSwitcher extends Backbone.View

  el: ".channel-switcher-contents"

  loader: (new Loader()).modules
  modules: [ChatClient, CodeClient, DrawingClient, CallClient, InfoClient]

  initialize: ->
    _.bindAll.apply(_, [this].concat(_.functions(this)))

    @sortedChannelNames = []
    @channels           = {}

    joinChannels        = window.localStorage.getObj("joined_channels") or []
    storedActiveChannel = window.localStorage.getObj("activeChannel")

    # some users don't like being in channel '/' on start
    joinChannels.unshift "/" if OPTIONS.join_default_channel
    joinChannels = _.uniq(joinChannels)

    # node_webkit cannot specify channel to join via URL
    unless window.ua.node_webkit
      channelFromSlug = window.location.pathname
      if joinChannels.indexOf(channelFromSlug) < 0
        storedActiveChannel = channelFromSlug
        joinChannels.push channelFromSlug

    for channel in joinChannels
      @joinChannel channel

    # join and show the last active channel immediately
    if storedActiveChannel
      @showChannel storedActiveChannel
    else if joinChannels.length
      @showChannel joinChannels[0]




    @attachEvents()
    $(window).on "unload", @quickKill

  attachEvents: ->

    window.events.on "showChannel", (channel) =>
      @showChannel channel

    window.events.on "joinChannel", (channel) =>
      @joinAndShowChannel channel

    window.events.on "leaveChannel", (channel) =>
      if channel
        @leaveChannel channel
      else
        @leaveChannel @activeChannel

    window.events.on "channelPassword", (data) =>
      window.events.trigger "channelPassword:#{@activeChannel}",
        password: data.password

    # show an input after clicking "+ Join Channel"
    $(document).on "click", ".j-channel-btn.join", =>
      if true
        channelName = prompt("Join which channel?")
        @joinAndShowChannel channelName
      else
        @$el.find("input.channel-name").toggle()

    # kill the channel when clicking the channel button's close icon
    @$el.on "click", ".channels .j-channel-btn .close", (ev) =>
      $chatButton = $(ev.currentTarget).parents(".j-channel-btn")
      channel = $chatButton.data("channel")
      ev.stopPropagation()
      ev.preventDefault()
      @leaveChannel channel

    # make the channel corresponding to the clicked channel button active:
    @$el.on "click", ".channels .j-channel-btn", (ev) =>
      channel = $(ev.currentTarget).data("channel")
      @showChannel channel

    window.events.on "nextChannel", @showNextChannel
    window.events.on "previousChannel", @showPreviousChannel

    window.events.on "chat:activity", (data) =>
      @channelActivity data


  quickKill: ->

    # https://github.com/qq99/echoplexus/issues/118
    # so the server doesn't attempt to keep them alive for any more than necessary, the client should be nice and tell us it's leaving
    _.each @channels, (channel) ->
      _.each channel.get("modules"), (module) ->
        module.view.kill()



  leaveChannel: (channelName) ->
    # don't leave an undefined channel or the last channel
    return if (typeof channelName is "undefined") or (@sortedChannelNames.length is 1)

    channelModel = @channels[channelName]

    channelViews = channelModel.get("modules")

    # remove the views, then their $els
    _.each channelViews, (module, key) ->
      module.view.kill()
      module.view.$el.remove()

    channelModel.get("button").destroy()

    # update / delete references:
    @showPreviousChannel() if channelName == @activeChannel # show them something while we quit this
    @sortedChannelNames = _.uniq _.without(@sortedChannelNames, channelName)
    delete @channels[channelName]

    # update stored channels for revisit/refresh
    window.localStorage.setObj "joined_channels", @sortedChannelNames

  showNextChannel: ->
    console.log @activeChannel
    return  unless @hasActiveChannel()
    activeChannelIndex = _.indexOf(@sortedChannelNames, @activeChannel)
    targetChannelIndex = activeChannelIndex + 1

    # prevent array OOB
    targetChannelIndex = targetChannelIndex % @sortedChannelNames.length
    @showChannel @sortedChannelNames[targetChannelIndex]

  showPreviousChannel: ->
    return  unless @hasActiveChannel()
    activeChannelIndex = _.indexOf(@sortedChannelNames, @activeChannel)
    targetChannelIndex = activeChannelIndex - 1

    # prevent array OOB
    targetChannelIndex = @sortedChannelNames.length - 1  if targetChannelIndex < 0
    @showChannel @sortedChannelNames[targetChannelIndex]

  hasActiveChannel: ->
    typeof @activeChannel isnt "undefined"

  showChannel: (channelName) ->
    channel = @channels[channelName]
    return if !channel
    if channel.isPrivate && !channel.authenticated
      window.events.trigger "showPrivateOverlay"
    else
      window.events.trigger "hidePrivateOverlay"

    channelsToDeactivate = _.without(_.keys(@channels), channelName)

    # tell the views to deactivate
    _.each channelsToDeactivate, (channelName) =>
      @channels[channelName].get("button").setInactive()
      _.each @channels[channelName].get("modules"), (module) ->
        module.view.$el.hide()
        module.view.trigger "hide"

    channel.get("button").setActive()

    # send events to the view we're showing:
    _.each channel.get("modules"), (module) ->
      module.view.$el.show()
      module.view.trigger "show"

    # keep track of which one is currently active
    @activeChannel = channelName

    # allow the user to know that his channel can be joined via URL slug by updating the URL
    # replaceState rather than pushing to keep Back/Forward intact && because we have no other option to perform here atm
    unless window.ua.node_webkit
      history.replaceState null, "", channelName  if history.replaceState

    # keep track of which one we were viewing:
    window.localStorage.setObj "activeChannel", channelName

    window.events.trigger "unidle"

  channelActivity: (data) ->
    fromChannel = data.channelName

    # if we hear that there's activity from a channel, but we're not looking at it, add a style to the button to notify the user:
    $("[data-channel='" + fromChannel + "']", @$el).addClass "activity"  if fromChannel isnt @activeChannel

  joinChannel: (channelName) ->
    if !@channels[channelName]?
      cryptokey = window.localStorage.getItem("chat:cryptokey:#{channelName}")
      cryptokey = undefined if cryptokey == ''

      button = new ChannelButton({channelName: channelName})

      channel = new Backbone.Model
        button: button
        clients: new ClientsCollection()
        modules: []
        authenticated: false
        isPrivate: false
        cryptokey: cryptokey

      # create an instance of each module:
      _.each @modules, (ClientModule, idx) =>
        if !_.isFunction(ClientModule)
          console.error 'Supplied module is not a callable function'
          return

        return  unless _.isFunction(ClientModule)
        modInstance =
          view: new ClientModule(
            channel: channel
            room: channelName
            config:
              host: window.SOCKET_HOST

            module: @loader[idx]
          )
          config: @loader[idx]

        modInstance.view.$el.hide()
        channel.get("modules").push modInstance

      @channels[channelName] = channel
      @loading -= 1

      @attachChannelButton(button)

      @render()

    @sortedChannelNames.push channelName
    @sortedChannelNames = _.sortBy(@sortedChannelNames, (key) ->
      key
    )
    @sortedChannelNames = _.uniq(@sortedChannelNames)

    # listen for leave events for the newly created channel
    window.events.on "leave:" + channelName, =>
      @leaveChannel channelName


    # update stored channels for revisit/refresh
    window.localStorage.setObj "joined_channels", @sortedChannelNames

  attachChannelButton: (buttonView) ->
    @$el.append buttonView.$el

  render: ->
    channelNames = _.sortBy(_.keys(@channels), (key) ->
      key
    )

    # clear out old pane:
    _.each @channels, (channel, channelName) ->
      channelViews = channel.get("modules")
      _.each channelViews, (module) ->
        if module.config?
          $("#" + module.config.section).append module.view.$el  unless $("." + module.view.className + "[data-channel='" + channelName + "']").length



  joinAndShowChannel: (channelName) ->
    return  if typeof channelName is "undefined" or channelName is null # prevent null channel names
    # keep channel names consistent with URL slug
    channelName = "/" + channelName  if channelName.charAt(0) isnt "/"
    @joinChannel channelName
    @showChannel channelName

