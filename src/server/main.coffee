require("coffee-script")
config           = require("./config.js").Configuration # deploy specific configuration
express          = require("express")
_                = require("underscore")
Backbone         = require("backbone")
crypto           = require("crypto")
fs               = require("fs")
uuid             = require("node-uuid")
redis            = require("redis")
sio              = require("socket.io")
spawn            = require("child_process").spawn
async            = require("async")
path             = require("path")
ChatServer       = require("./ChatServer.coffee").ChatServer
CodeServer       = require("./CodeServer.coffee").CodeServer
DrawServer       = require("./DrawServer.coffee").DrawServer
CallServer       = require("./CallServer.coffee").CallServer
UserServer       = require("./UserServer.coffee").UserServer
EventBus         = new Backbone.Model
app              = express()

# config:
ROOT_FOLDER      = path.dirname(__dirname)
PUBLIC_FOLDER    = ROOT_FOLDER + "/../public"
SANDBOXED_FOLDER = PUBLIC_FOLDER + "/sandbox"

console.log "Root:            #{ROOT_FOLDER}"
console.log "Public:          #{PUBLIC_FOLDER}"
console.log "Sandboxed:       #{SANDBOXED_FOLDER}"


# if we're using node's ssl, we must supply it the certs and create the server as https
# proxying via nginx allows us to use a simple http server (and connections will be upgraded)

# Custom objects:
# shared with the client:
urlRoot = ->
  if config.host.USE_PORT_IN_URL
    config.host.SCHEME + "://" + config.host.FQDN + ":" + config.host.PORT + "/"
  else
    config.host.SCHEME + "://" + config.host.FQDN + "/"

# Web server init:

# xferc means 'transfer config'

# MW: MiddleWare
authMW = (req, res, next) ->
  console.log req.get("channel"), req.get("from_user"), req.get("antiforgery_token"), req.get("using_permission")
  if not xferc or not xferc.enabled
    res.send 500, "Not enabled."
    return
  EventBus.trigger "has_permission",
    permission: req.get("Using-Permission")
    channel: req.get("Channel")
    from_user: req.get("From-User")
    antiforgery_token: req.get("Antiforgery-Token")
  , (err, message) ->
    if err
      res.send err, message
      return
    next()

if config.redis
  redisC = redis.createClient(config.redis.port, config.redis.host)
else
  redisC = redis.createClient()
if config.ssl.USE_NODE_SSL
  protocol = require("https")
  privateKey = fs.readFileSync(config.ssl.PRIVATE_KEY).toString()
  certificate = fs.readFileSync(config.ssl.CERTIFICATE).toString()
  credentials =
    key: privateKey
    cert: certificate

  server = protocol.createServer(credentials, app)
else
  protocol = require("http")
  server = protocol.createServer(app)
index = "public/index.dev.html"
index = "public/index.build.html"  if fs.existsSync(PUBLIC_FOLDER + "/index.build.html")
console.log "Using index: " + index
Client = require("../client/client.js").ClientModel
Clients = require("../client/client.js").ClientsCollection
REGEXES = require("../client/regex.js").REGEXES

app.use express.static(PUBLIC_FOLDER)

xferc = config.server_hosted_file_transfer
app.use express.limit(xferc.size_limit)  if xferc?.enabled and xferc.size_limit

bodyParser = express.bodyParser(uploadDir: SANDBOXED_FOLDER)

# always server up the index
#
# receive files
app.post "/*", authMW, bodyParser, (req, res, next) ->
  file = req.files.user_upload
  uploadPath = file.path
  newFilename = uuid.v4() + "." + file.name.replace(RegExp(" ", "g"), "_")
  finalPath = SANDBOXED_FOLDER + "/" + newFilename
  serverPath = urlRoot() + "sandbox/" + newFilename
  console.log newFilename

  # delete the file immediately if the message was malformed
  if typeof req.get("From-User") is "undefined" or typeof req.get("Channel") is "undefined"
    fs.unlink uploadPath, (error) ->
      console.log error.message  if error

    return

  # rename it with a uuid + the user's filename
  fs.rename uploadPath, finalPath, (error) ->
    if error
      res.send error: "Ah crap! Something bad happened"
      return
    res.send path: serverPath
    EventBus.trigger "file_uploaded:" + req.get("Channel"),
      from_user: req.get("From-User")
      path: serverPath



app.get "/api/*", (req, res) ->
  if req.route.params[0].indexOf("channels") isnt -1
    res.set "Content-Type", "application/json"
    publicChannelInformation = []
    publicChannels = Channels.where(private: false)
    i = 0

    while i < publicChannels.length
      chan = publicChannels[i]
      chanJson = chan.toJSON()

      # extract some non-collection information:
      chanJson.numActiveClients = chan.clients.where(idle: false).length
      chanJson.numClients = chan.clients.length
      delete chanJson.topicObj

      publicChannelInformation.push chanJson
      i++
    _.sortBy publicChannelInformation, "numActiveClients"
    res.write JSON.stringify(publicChannelInformation)
    res.end()

app.get "/*", (req, res) ->
  res.sendfile index

server.listen config.host.PORT
console.log "Listening on port", config.host.PORT

# SocketIO init:
sio = sio.listen(server)
sio.enable "browser client minification"
sio.enable "browser client gzip"
sio.set "log level", 1

# use db 15:
redisC.select 15, (err, reply) ->
  ChannelStructures = require("./Channels.js").ChannelStructures(redisC, EventBus)
  ChannelModel = ChannelStructures.ServerChannelModel
  Channels = new ChannelStructures.ChannelsCollection()
  chatServer = new ChatServer sio, redisC, EventBus, Channels, ChannelModel # start up the chat server
  chatServer.start
    error: (err, socket, channel, client, data) ->
      room = channel.get("name")

      if err
        if err instanceof ApplicationError.Authentication
          if !data.reconnect
            socket.in(room).emit("chat:" + room, serverSentMessage({
              body: "This channel is private.  Please type /password [channel password] to join"
            }, room))
          socket.in(room).emit("private:" + room)
        else
          socket.in(room).emit("chat:" + room, serverSentMessage({
            body: err.message
          }, room))

          DEBUG && console.log("ChatServer: ", err)
        return
    success: (namespace, socket, channel, client,data) ->
      room = channel.get("name")
      DEBUG && console.log("Client joined ", room)
      subscribeSuccess(socket, client, channel)

      # channel.initialized is inelegant (since it clearly has been)
      # and other modules might use it.
      # hotfix for now, real fix later
      if channel.initialized == false
        # only bind these once *ever*
        channel.clients.on "change", (changed) ->
          clientChanged(socket, channel, changed)

        channel.clients.on "remove", (removed) ->
          clientRemoved(socket, channel, removed)

        channel.initialized = true

        # listen for file upload events
        EventBus.on "file_uploaded:#{room}", (data) ->
          # check to see that the uploader someone actually in the channel
          fromClient = channel.clients.findWhere({id: data.from_user})

          if fromClient?
            uploadedFile = serverSentMessage({
              body: fromClient.get("nick") + " just uploaded: " + data.path
            }, room)

            storePersistent uploadedFile, room, (err, msg) ->
              if err
                console.log("Error persisting a file upload notification to redis", err.message, msg)

              sio.of(CHATSPACE).in(room).emit("chat:" + room, msg)

  codeServer = new CodeServer sio, redisC, EventBus, Channels
  codeServer.start
    error: (err, socket, channel, client) ->
      if err
        DEBUG && console.log("CodeServer: ", err)
    success: (namespace, socket, channel, client) ->
      console.log "CodeServer started"
      cc = spawnCodeCache(namespace)
      socket.in(namespace).emit("code:authoritative_push:#{namespace}", cc.syncToClient());

  # drawServer = new DrawServer sio, redisC, EventBus, Channels
  # drawServer.start
  #   error: (err, socket, channel, client) ->
  #     if err
  #       return
  #   success: (namespace, socket, channel, client) ->
  #     room = channel.get("name")

  #     # play back what has happened
  #     socket.emit("draw:replay:" + namespace, channel.replay)

  # callServer = new CallServer sio, redisC, EventBus, Channels
  # callServer.start
  #   error: (err, socket, channel, client) ->
  #       if (err)
  #           console.log("CallServer: ", err)

  #   success: (namespace, socket, channel, client) ->
  #       room = channel.get('name')
  #       socket.emit "status:#{room}", active: !_.isEmpty(channel.call)

  # userServer sio, redisC, EventBus, Channels
