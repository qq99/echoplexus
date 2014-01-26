versions       = require('./version.coffee')
_              = require('underscore')
AbstractServer = require('./AbstractServer.coffee').AbstractServer
Client         = require('../client/client.js').ClientModel
Clients        = require('../client/client.js').ClientsCollection
config         = require('./config.coffee').Configuration
DEBUG          = config.DEBUG

# this server is meant to expose all manners of metadata about the host
# that is operating echoplexus
# for instance, a client could query capabilities or client versions supported
module.exports.InfoServer = class InfoServer extends AbstractServer

  name: "InfoServer"
  namespace: "/info"

  events:
    "info:latest_supported_client_version": (namespace, socket, channel, client, data) ->
      room = channel.get("name")

      socket.in(room).emit "info:latest_supported_client_version:#{room}", versions.LATEST_SUPPORTED_CLIENT_VERSION
