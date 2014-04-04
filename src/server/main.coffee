require("coffee-script")
config           = require("./config.coffee").Configuration # deploy specific configuration
redis_db         = config.redis?.select || 15
redisC           = require("./RedisClient.coffee").RedisClient(config.redis?.port, config.redis?.host, redis_db)
express          = require("express")
_                = require("underscore")
Backbone         = require("backbone")
crypto           = require("crypto")
fs               = require("fs")
ApplicationError = require("./Error.js.coffee")
uuid             = require("node-uuid")
sio              = require("socket.io")
spawn            = require("child_process").spawn
async            = require("async")
path             = require("path")
ChatServer       = require("./ChatServer.coffee").ChatServer
CodeServer       = require("./CodeServer.coffee").CodeServer
DrawServer       = require("./DrawServer.coffee").DrawServer
CallServer       = require("./CallServer.coffee").CallServer
InfoServer       = require("./InfoServer.coffee").InfoServer
# UserServer     = require("./UserServer.coffee").UserServer
EventBus         = require("./EventBus.coffee").EventBus()
app              = express()
GithubWebhook    = require("./GithubWebhookIntegration.coffee")

# config:
ROOT_FOLDER      = path.dirname(__dirname)
PUBLIC_FOLDER    = ROOT_FOLDER + "/../public"
SANDBOXED_FOLDER = PUBLIC_FOLDER + "/sandbox"

config.ROOT_FOLDER      = ROOT_FOLDER
config.PUBLIC_FOLDER    = PUBLIC_FOLDER
config.SANDBOXED_FOLDER = SANDBOXED_FOLDER

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

# MW: MiddleWare
authMW = (req, res, next) ->
  # xferc means 'transfer config'
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
#index = "public/index.build.html"  if fs.existsSync(PUBLIC_FOLDER + "/index.build.html")
console.log "Using index: " + index
Client = require("../client/client.js").ClientModel
Clients = require("../client/client.js").ClientsCollection
REGEXES = require("../client/regex.js").REGEXES

express.static.mime.define {'application/x-web-app-manifest+json': ['webapp']}

app.use express.static(PUBLIC_FOLDER)

xferc = config.server_hosted_file_transfer
app.use express.limit(xferc.size_limit)  if xferc.enabled and xferc.size_limit

bodyParser = express.bodyParser(uploadDir: SANDBOXED_FOLDER)
app.use express.bodyParser()

# endpoint for github
app.post "/api/github/postreceive/:token", (req, res) ->

  GithubWebhook.verifyAllowedRepository req.params.token, (err, room) ->
    if err
      res.send(err.toString(), 404)
    if room
      try
        payload = JSON.parse(req.body.payload)
        console.log payload
        message = GithubWebhook.prettyPrint(payload)
        EventBus.trigger("github:postreceive:#{room}", message)
      catch e
        console.log "Failed to parse data from GitHub", e

      res.send("OK", 200)
      res.end()

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
      console.log error
      res.send error: "Ah crap! Something bad happened"
      return
    res.send path: serverPath
    EventBus.trigger "file_uploaded:" + req.get("Channel"),
      from_user: req.get("From-User")
      path: serverPath

# get list of channels and users in them
app.get "/api/channels", (req, res) ->
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

ChannelStructures = require("./Channels.js.coffee")
ChannelModel = ChannelStructures.ServerChannelModel
Channels = new ChannelStructures.ChannelsCollection

redisC.select redis_db, (err, reply) ->
  chatServer = new ChatServer sio, Channels, ChannelModel # start up the chat server
  chatServer.start()

  codeServer = new CodeServer sio, Channels, ChannelModel
  codeServer.start()

  drawServer = new DrawServer sio, Channels, ChannelModel
  drawServer.start()

  callServer = new CallServer sio, Channels, ChannelModel
  callServer.start()

  infoServer = new InfoServer sio, Channels, ChannelModel
  infoServer.start()

