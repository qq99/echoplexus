(->
  requestAnimationFrame = window.requestAnimationFrame or window.mozRequestAnimationFrame or window.webkitRequestAnimationFrame or window.msRequestAnimationFrame
  window.requestAnimationFrame = requestAnimationFrame
)()
define ["jquery", "underscore", "backbone", "client", "keymaster", "text!modules/draw/templates/drawing.html"], ($, _, Backbone, Client, key, drawingTemplate) ->
  TimeCapsule = ->
    time = 0
    @getLapse = ->
      time = (new Date()).getTime()  if time is 0
      newTime = (new Date()).getTime()
      delay = newTime - time
      time = newTime
      delay

    this
  ColorModel = Client.ColorModel
  TOOLS =
    PEN: 1
    ERASER: 2


  # this is really the JSHTML code client:
  Backbone.View.extend
    className: "drawingClient"
    template: _.template(drawingTemplate)
    initialize: (opts) ->
      self = this
      _.bindAll this

      #The current canvas style
      @style =
        tool: TOOLS.PEN
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
      @on "show", ->
        DEBUG and console.log("drawing_client:show")
        self.$el.show()

      @on "hide", ->
        DEBUG and console.log("drawing_client:hide")
        self.$el.hide()

      @layerBackground = @$el.find("canvas.background")[0]

      #Background (where everything gets drawn ultimately)
      @ctx = @layerBackground.getContext("2d")


    #A timecapsule (for recording timelapses at a later date)
    #this.timeCapsule = null;
    kill: ->
      self = this
      DEBUG and console.log("killing DrawingClientView", self.channelName)

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

      #this.timer = new TimeCapsule();
      @movePath _.extend(coords,
        beginPath: true
      )

    movePath: (coords) ->
      return  unless @cursorDown
      ctx = @ctx

      #Set up the coordinates
      #coords.lapse = this.timer.getLapse();
      coords.style = _.clone(@style)  if coords.beginPath

      # Push coords to current path.
      @buffer.push coords

      #Stream the point out
      @socket.emit "draw:line:" + @channelName,
        coord: coords

      @drawLine ctx, @buffer

    stopPath: (coords) ->

      #Record what we just drew to the foreground and clean up
      @movePath _.extend(coords,
        endPath: true
      )
      @cursorDown = false


    #if (dstEraser) {
    #                layer1.style.display = "block";
    #                ctx1.clearRect(0, 0, innerWidth, innerHeight);
    #            }
    trash: ->
      @ctx.clearRect 0, 0, @layerBackground.width, @layerBackground.height

    attachEvents: ->
      self = this
      @samplePoints = _.throttle(@movePath, 40)
      @$el.on "mousedown", ".canvas-area", (ev) ->
        self.startPath self.getCoords(ev)

      @$el.on "mouseup", ".canvas-area", (ev) ->
        self.stopPath self.getCoords(ev)

      @$el.on "mousemove", ".canvas-area", (ev) ->
        return  unless self.cursorDown
        self.samplePoints self.getCoords(ev)

      @$el.on "click", ".tool.trash", ->
        DEBUG and console.log("emitting trash event")
        self.trash()
        self.socket.emit "trash:" + self.channelName, {}

      @$el.on "click", ".tool.eraser", ->
        self.changeTool "ERASER"

      @$el.on "click", ".swatch", (ev) ->
        self.style.strokeStyle = $(this).data("color")

      @$el.on "click", ".tool.pen", ->
        self.changeTool "PEN"

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

      key "]", ->
        self.style.lineWidth += 0.25  if self.$el.is(":visible")

      key "[", ->
        self.style.lineWidth -= 0.25  if self.$el.is(":visible")

      key ",", ->
        if self.$el.is(":visible")

          #Increment brushes
          tools = _.keys(TOOLS)
          tool = self.style.tool
          tool = 0  if tool >= tools.length
          self.changeTool tools[tool]

      key ".", ->
        if self.$el.is(":visible")

          #Decrement brushes
          tools = _.keys(TOOLS)
          tool = self.style.tool - 2
          tool = tools.length - 1  if tool < 0
          self.changeTool tools[tool]


    showPenOptions: ->

    postSubscribe: ->

    refresh: ->

    drawLine: (ctx, path) ->
      self = this

      # commenting out to test Issue #141 (seems data is lost while drawing, dashed lines)
      # window.requestAnimationFrame(function(){
      ctx.save()

      #Load the style
      _.extend ctx, path[0].style

      #If eraser, set to erase mode
      if path[0].style.tool is TOOLS.ERASER
        ctx.globalAlpha = 1
        ctx.globalCompositeOperation = "destination-out"

      #Draw the path
      self.catmull path.slice(Math.max(0, path.length - 4), path.length), ctx
      ctx.restore()


    # });
    listen: ->
      self = this
      socket = @socket
      @socketEvents =
        "draw:line": (msg) ->

          #Draw to the foreground context
          ctx = self.ctx

          #Initialize the path if it wasn't already initialized
          path = self.paths[msg.id] = (self.paths[msg.id] or [])

          #If the path was just started, clear it
          path = self.paths[msg.id] = []  if msg.coord.beginPath

          #Add the coordinate to the path
          path.push msg.coord

          #Draw the line
          self.drawLine ctx, path

        trash: ->
          self.trash()

        "draw:replay": (buffer) ->

          #Message is the entire draw buffer(will be huge!(probably))
          #Although we have recieved a ton of data, to combat this we can render n points at a time, and then wait
          #Draw to the foreground context
          ctx = self.ctx
          paths = {}
          _.each buffer, (msg) ->

            #Initialize the path if it wasn't already initialized
            path = paths[msg.id] = (paths[msg.id] or [])

            #If the path was just started, clear it
            path = paths[msg.id] = []  if msg.coord.beginPath

            #Add the coordinate to the path
            path.push msg.coord

            #Add to the animation queue
            self.drawLine ctx, _.clone(path)


      _.each @socketEvents, (value, key) ->

        # listen to a subset of event
        socket.on key + ":" + self.channelName, value


      # initialize the channel
      socket.emit "subscribe",
        room: self.channelName
      , @postSubscribe

      #On successful reconnect, attempt to rejoin the room
      socket.on "reconnect", ->

        #Resend the subscribe event
        socket.emit "subscribe",
          room: self.channelName
          reconnect: true
        , @postSubscribe


    changeTool: (tool) ->
      _.each _.omit(TOOLS, tool), (v, key) ->
        $(".tool." + key.toLowerCase()).removeClass "tool-highlight"

      $(".tool." + tool.toLowerCase()).addClass "tool-highlight"
      @style.tool = TOOLS[tool]

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

