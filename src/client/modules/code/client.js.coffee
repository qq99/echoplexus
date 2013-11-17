define ["jquery", "underscore", "backbone", "codemirror", "modules/code/SyncedEditor", "text!modules/code/templates/jsCodeRepl.html", "codemirror-xml", "codemirror-css", "codemirror-js", "codemirror-html"], ($, _, Backbone, CodeMirror, SyncedEditor, jsCodeReplTemplate) ->

  # this is really the JSHTML code client:
  Backbone.View.extend
    className: "codeClient"
    htmlEditorTemplate: _.template(jsCodeReplTemplate)
    initialize: (opts) ->
      self = this
      _.bindAll this
      @channel = opts.channel
      @channelName = opts.room
      @config = opts.config
      @module = opts.module
      @listen()
      @render()

      # debounce a function for auto-repling
      @doREPL = _.debounce(->
        self.refreshIframe()
        self._repl()
      , 700)
      @editors =
        js: @editorTemplates.SimpleJS($(".jsEditor", @$el)[0])
        html: @editorTemplates.SimpleHTML($(".htmlEditor", @$el)[0])


      # currently triggered when user selects another channel:
      # perhaps should also be triggered when a user chooses a different tab
      @on "show", @show
      @on "hide", @hide

      #Is the REPL loaded?
      @isIframeAvailable = false

      #Wether to evaluate immediately on REPL load
      @runNext = false

    initializeEditors: ->
      syncedEditor = new SyncedEditor()
      @syncedJs = new syncedEditor(
        clients: @channel.clients
        host: @config.host
        room: @channelName
        subchannel: "js"
        editor: @editors["js"]
      )
      @syncedHtml = new syncedEditor(
        clients: @channel.clients
        host: @config.host
        room: @channelName
        subchannel: "html"
        editor: @editors["html"]
      )
      @repl = $(".jsREPL .output", @$el)
      @attachEvents()

    hide: ->
      DEBUG and console.log("code_client:hide")
      @$el.hide()
      if @syncedJs and @syncedHtml
        @syncedJs.trigger "hide"
        @syncedHtml.trigger "hide"

      # turn off live-reloading if we hide this view
      # don't want to execute potential DoS code that was inserted while we were away
      @$livereload_checkbox.attr "checked", false  if @$livereload_checkbox and @$livereload_checkbox.is(":checked")

    show: ->
      DEBUG and console.log("code_client:show")
      @$el.show()
      unless @editorsInitialized
        @editorsInitialized = true # lock it so it can only happen once in the lifetime
        @initializeEditors()
      @syncedJs.trigger "show"
      @syncedHtml.trigger "show"

    kill: ->
      self = this
      console.log "killing CodeClientView", self.channelName
      @syncedJs and @syncedJs.kill()
      @syncedHtml and @syncedHtml.kill()

    livereload: ->

      # only automatically evaluate the REPL if the user has opted in

      #Reload the iframe (causes huge amounts of lag)
      #this.refreshIframe();
      @doREPL()  if @$livereload_checkbox and @$livereload_checkbox.is(":checked")

    attachEvents: ->
      self = this
      @listenTo @syncedJs, "eval", @livereload
      @listenTo @syncedHtml, "eval", @livereload
      window.events.on "sectionActive:" + @module.section, ->
        self.refresh()

      $(window).on "message", (e) ->
        if e.originalEvent.data is "ready"
          self.isIframeAvailable = true
          if self.runNext
            self._repl()
            self.runNext = false
          return
        data = undefined
        try
          data = JSON.parse(decodeURI(e.originalEvent.data))
          self.updateREPL data.result  if data.channel is self.channelName
        catch ex
          self.updateREPL ex.toString()

      @$el.on "click", ".evaluate", (ev) ->
        ev.preventDefault()
        ev.stopPropagation()
        self._repl() # doesn't need to be the debounced version since the user is triggering it purposefully

      @$el.on "click", ".refresh", (ev) ->
        ev.preventDefault()
        ev.stopPropagation()
        self.refreshIframe()


    refresh: ->
      _.each @editors, (editor) ->
        editor.refresh()


    refreshIframe: ->
      iframe = $("iframe.jsIframe", @$el)[0]
      iframe.src = iframe.src
      @isIframeAvailable = false

    updateREPL: (result) ->
      if _.isObject(result)
        result = JSON.stringify(result)
      else if typeof result is "undefined"
        result = "undefined"
      else
        result = result.toString()
      @repl.text result

    evaluate: (code) ->

      # var iframe = document.getElementById("repl-frame").contentWindow;
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
      unless @isIframeAvailable
        @runNext = true
        return
      code = _.object(_.map(@editors, (editor, key) ->
        [key, editor.getValue()]
      ))

      # do HTML first so it's available to the user JS:
      #this.evaluateHTML(html);
      #this.evaluateJS(js);
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

