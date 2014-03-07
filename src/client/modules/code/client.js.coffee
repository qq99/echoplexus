jsCodeReplTemplate  = require('./templates/jsCodeRepl.html')
SyncedEditor        = require('./SyncedEditor.js.coffee').SyncedEditor

module.exports.CodeClient = class CodeClient extends Backbone.View
  # this is really the JS&HTML code client:

  className: "codeClient"
  htmlEditorTemplate: jsCodeReplTemplate

  initialize: (opts) ->
    _.bindAll this
    @channel = opts.channel
    @channelName = opts.room
    @config = opts.config
    @module = opts.module
    @listen()
    @render()

    # debounce a function for auto-repling
    @doREPL = _.debounce(=>
      @_repl()
    , 700)

    @editors =
      js: @editorTemplates.SimpleJS($(".jsEditor", @$el)[0])
      html: @editorTemplates.SimpleHTML($(".htmlEditor", @$el)[0])


    # currently triggered when user selects another channel:
    # perhaps should also be triggered when a user chooses a different tab
    @on "show", @show
    @on "hide", @hide

    #Is the REPL loaded?
    @isIframeAvailable = true

    #Wether to evaluate immediately on REPL load
    @runNext = false

  initializeEditors: ->
    @syncedJs = new SyncedEditor
      clients: @channel.get("clients")
      host: @config.host
      room: @channelName
      subchannel: "js"
      editor: @editors["js"]
      channel: @channel

    @syncedHtml = new SyncedEditor
      clients: @channel.get("clients")
      host: @config.host
      room: @channelName
      subchannel: "html"
      editor: @editors["html"]
      channel: @channel

    @repl = $(".jsREPL .output", @$el)
    @attachEvents()

  hide: ->
    @$el.hide()
    if @syncedJs and @syncedHtml
      @syncedJs.trigger "hide"
      @syncedHtml.trigger "hide"

    # turn off live-reloading if we hide this view
    # don't want to execute potential DoS code that was inserted while we were away
    @$livereload_checkbox.attr "checked", false  if @$livereload_checkbox and @$livereload_checkbox.is(":checked")

  show: ->
    @$el.show()
    unless @editorsInitialized
      @editorsInitialized = true # lock it so it can only happen once in the lifetime
      @initializeEditors()
    @syncedJs.trigger "show"
    @syncedHtml.trigger "show"

  kill: ->
    window.events.off null, null, this
    @syncedJs and @syncedJs.kill()
    @syncedHtml and @syncedHtml.kill()

  livereload: ->
    # only automatically evaluate the REPL if the user has opted in
    @doREPL()  if @$livereload_checkbox and @$livereload_checkbox.is(":checked")

  attachEvents: ->
    @listenTo @syncedJs, "eval", @livereload
    @listenTo @syncedHtml, "eval", @livereload

    window.events.on "sectionActive:" + @module.section, ->
      @refresh()
    , this

    $(window).on "message", (e) =>
      try
        data = JSON.parse(decodeURI(e.originalEvent.data))
        @updateREPLText data.result  if data.channel is @channelName
      catch ex
        @updateREPLText ex.toString()

    @$el.on "click", ".evaluate", (ev) =>
      ev.preventDefault()
      ev.stopPropagation()
      @_repl() # doesn't need to be the debounced version since the user is triggering it purposefully

    @$el.on "click", ".refresh", (ev) =>
      ev.preventDefault()
      ev.stopPropagation()
      @refreshIframe()

  refresh: ->
    _.each @editors, (editor) ->
      editor.refresh()

  refreshIframe: ->
    iframe = $("iframe.jsIframe", @$el)[0]
    iframe.src = iframe.src
    @isIframeAvailable = false

  updateREPLText: (result) ->
    if _.isObject(result)
      result = JSON.stringify(result)
    else if typeof result is "undefined"
      result = "undefined"
    else
      result = result.toString()
    @repl.text result

  evaluate: (code) ->

    if typeof code is "undefined"
      @repl.text ""
      return
    iframe = $("iframe.jsIframe", @$el)[0]

    #Send the message
    iframe.contentWindow.postMessage encodeURI(JSON.stringify(
      type: "js"
      code: code
      channel: @channelName
    )), "*"

  _repl: ->
    if not @isIframeAvailable
      @refreshIframe()

    code = _.object(_.map(@editors, (editor, key) ->
      [key, editor.getValue()]
    ))

    @evaluate code

  editorTemplates:
    SimpleJS: (domEl) ->
      CodeMirror.fromTextArea domEl,
        lineNumbers: true
        mode: "text/javascript"
        theme: "monokai"
        matchBrackets: true
        highlightActiveLine: true
        continueComments: "Enter"

    SimpleHTML: (domEl) ->
      CodeMirror.fromTextArea domEl,
        lineNumbers: true
        mode: "text/html"
        theme: "monokai"

  listen: ->

  render: ->
    @$el.html @htmlEditorTemplate()
    @$el.attr "data-channel", @channelName
    @$livereload_checkbox = @$el.find("input.livereload")

