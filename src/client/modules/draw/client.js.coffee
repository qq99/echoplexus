drawingTemplate   = require('./templates/drawing.html')
ColorModel        = require('../../client.js.coffee').ColorModel

module.exports.DrawingClient = class DrawingClient extends Backbone.View
  TOOLS:
    PEN: 1
    ERASER: 2

  className: "drawingClient"
  template: drawingTemplate

  initialize: (opts) ->
    _.bindAll.apply(_, [this].concat(_.functions(this)))

    #The current canvas style
    @style =
      tool: @TOOLS.PEN
      globalAlpha: 1
      globalCompositeOperation: "source-over"
      strokeStyle: (new ColorModel()).toRGB()
      lineWidth: 10
      lineCap: "round"
      lineJoin: "round"

    @config = opts.config
    @module = opts.module
    @socket = io.connect(@config.host + "/draw")
    @channelName = opts.room

    #Initialize a path variable to hold the paths buffer as we recieve it from other clients
    @paths = {}
    @listen()
    @render()
    @attachEvents()

    @on "show", =>
      @$el.show()

    @on "hide", =>
      @$el.hide()

    @layerBackground = @$el.find("canvas.background")[0]

    #Background (where everything gets drawn ultimately)
    @ctx = @layerBackground.getContext("2d")

  kill: ->

  getCoords: (ev) ->
    if typeof ev.offsetX is "undefined"
      offset = $(ev.target).offset()
      x: ev.clientX - offset.left
      y: ev.clientY - offset.top
    else
      x: ev.offsetX
      y: ev.offsetY

  startPath: (coords) ->
    @cursorDown = true
    @buffer = []

    @movePath _.extend(coords, beginPath: true)

  movePath: (coords) ->
    return unless @cursorDown

    #Set up the coordinates
    #coords.lapse = this.timer.getLapse();
    coords.style = _.clone(@style)  if coords.beginPath

    # Push coords to current path.
    @buffer.push coords

    #Stream the point out
    @socket.emit "draw:line:" + @channelName, coord: coords

    @drawLine @ctx, @buffer

  stopPath: (coords) ->

    #Record what we just drew to the foreground and clean up
    @movePath _.extend(coords, endPath: true)
    @cursorDown = false

  trash: ->
    @ctx.clearRect 0, 0, @layerBackground.width, @layerBackground.height

  attachEvents: ->
    @samplePoints = _.throttle(@movePath, 40)

    @$el.on "mousedown", ".canvas-area", (ev) =>
      @startPath @getCoords(ev)

    @$el.on "mouseup", ".canvas-area", (ev) =>
      @stopPath @getCoords(ev)

    @$el.on "mousemove", ".canvas-area", (ev) =>
      return unless @cursorDown
      @samplePoints @getCoords(ev)

    @$el.on "click", ".tool.trash", =>
      @trash()
      @socket.emit "trash:#{@channelName}", {}

    @$el.on "click", ".tool.eraser", =>
      @changeTool "ERASER"

    @$el.on "click", ".swatch", (ev) =>
      @style.strokeStyle = $(ev.currentTarget).data("color")
      @changeTool "PEN"

    @$el.on "click", ".tool.pen", =>
      @changeTool "PEN"

    @$el.on "click", ".tool.info", ->
      $(this).find(".tool-options").toggleClass "active"

    @$el.on "click", ".tool.color", ->
      options = $(this).find(".tool-options-contents")
      swatch = $("<div class=\"swatch\"></div>")
      options.html ""
      _(30).times ->
        randomColor = (new ColorModel()).toRGB()
        swatch.clone().css("background", randomColor).data("color", randomColor).appendTo options

      $(this).find(".tool-options").toggleClass "active"

    key "]", =>
      @style.lineWidth += 0.25  if @$el.is(":visible")

    key "[", =>
      @style.lineWidth -= 0.25  if @$el.is(":visible")

    key ",", =>
      if @$el.is(":visible")

        #Increment brushes
        tools = _.keys(@TOOLS)
        tool = @style.tool
        tool = 0  if tool >= tools.length
        @changeTool tools[tool]

    key ".", =>
      if @$el.is(":visible")

        #Decrement brushes
        tools = _.keys(@TOOLS)
        tool = @style.tool - 2
        tool = tools.length - 1  if tool < 0
        self.changeTool tools[tool]


  showPenOptions: ->

  postSubscribe: ->

  refresh: ->

  drawLine: (ctx, path) =>
    # commenting out to test Issue #141 (seems data is lost while drawing, dashed lines)
    ctx.save()

    #Load the style
    _.extend ctx, path[0].style

    #If eraser, set to erase mode
    if path[0].style.tool is @TOOLS.ERASER
      ctx.globalAlpha = 1
      ctx.globalCompositeOperation = "destination-out"

    #Draw the path
    @catmull path.slice(Math.max(0, path.length - 4), path.length), ctx
    ctx.restore()

  listen: ->
    socket = @socket
    @socketEvents =
      "draw:line": (msg) =>

        #Draw to the foreground context
        ctx = @ctx

        #Initialize the path if it wasn't already initialized
        path = @paths[msg.id] = (@paths[msg.id] or [])

        #If the path was just started, clear it
        path = @paths[msg.id] = []  if msg.coord.beginPath

        #Add the coordinate to the path
        path.push msg.coord

        console.log @

        #Draw the line
        @drawLine ctx, path

      trash: =>
        @trash()

      "draw:replay": (buffer) =>

        #Message is the entire draw buffer(will be huge!(probably))
        #Although we have recieved a ton of data, to combat this we can render n points at a time, and then wait
        #Draw to the foreground context
        ctx = @ctx
        paths = {}
        _.each buffer, (msg) =>

          #Initialize the path if it wasn't already initialized
          path = paths[msg.id] = (paths[msg.id] or [])

          #If the path was just started, clear it
          path = paths[msg.id] = []  if msg.coord.beginPath

          #Add the coordinate to the path
          path.push msg.coord

          #Add to the animation queue
          @drawLine ctx, _.clone(path)


    _.each @socketEvents, (value, key) =>

      # listen to a subset of event
      socket.on "#{key}:#{@channelName}", value


    # initialize the channel
    socket.emit "subscribe", room: @channelName, @postSubscribe

    #On successful reconnect, attempt to rejoin the room
    socket.on "reconnect", =>

      #Resend the subscribe event
      socket.emit "subscribe",
        room: @channelName
        reconnect: true
      , @postSubscribe


  changeTool: (tool) ->
    _.each _.omit(@TOOLS, tool), (v, key) ->
      $(".tool." + key.toLowerCase()).removeClass "tool-highlight"

    $(".tool." + tool.toLowerCase()).addClass "tool-highlight"
    @style.tool = @TOOLS[tool]

  render: ->
    @$el.html @template()
    @$el.attr "data-channel", @channelName


  #Catmull-Rom spline
  catmull: (path, ctx, tens) ->
    tension = 1 - (tens or 0)
    length = path.length - 3
    path.splice 0, 0, path[0]
    path.push path[path.length - 1]
    return  if length <= 0
    n = 0

    while n < length
      p1 = path[n]
      p2 = path[n + 1]
      p3 = path[n + 2]
      p4 = path[n + 3]
      if n is 0
        ctx.beginPath()
        ctx.moveTo p2.x, p2.y
      ctx.bezierCurveTo p2.x + (tension * p3.x - tension * p1.x) / 6, p2.y + (tension * p3.y - tension * p1.y) / 6, p3.x + (tension * p2.x - tension * p4.x) / 6, p3.y + (tension * p2.y - tension * p4.y) / 6, p3.x, p3.y
      n++
    ctx.stroke()

