_                   = require("underscore")
AbstractServer      = require("./AbstractServer.coffee").AbstractServer
config              = require("./config.coffee").Configuration
Client              = require("../client/client.js").ClientModel
Clients             = require("../client/client.js").ClientsCollection
DEBUG               = config.DEBUG

module.exports.CallServer = class CallServer extends AbstractServer

    name: "CallServer"
    namespace: "/call"

    events:
        "join": (namespace, socket, channel, client, data, ack) ->
            DEBUG && console.log 'client expressed interest in joining the call'

            room = channel.get("name")
            clientID = client.get("id")

            # if this is the first person joining the call, announce the call as in progress
            if _.isEmpty(channel.call)
                @sio.of(@namespace).in(room).emit "status:#{room}", active: true

            # add client to our memory
            channel.call[clientID] = socket

            # send all other peers the new peer
            socket.in(room).broadcast.emit "new_peer:#{room}", id: clientID

            # send new peer a list of all prior peers' IDs and his own ID
            ack connections: _.without(_.keys(channel.call),client.get('id')), you: clientID

        "leave": (namespace, socket, channel, client, data) ->
            room = channel.get("name")
            clientID = client.get("id")

            # let all others know that this client has left
            socket.in(room).broadcast.emit("remove_peer:#{room}", {
                id: clientID
            })

            # remove this client from our memory
            delete channel.call[clientID]

            # if the last person has left, the call status is false (no call in progress)
            if _.isEmpty(channel.call)
                @sio.of(@namepsace).in(room).emit "status:#{room}", active: false

            DEBUG && console.log("Client left, remaining: ", _.keys(channel.call).length)

        "ice_candidate": (namespace, socket, channel, client, data) ->
            DEBUG && console.log('Ice Candidate recieved from ' + client.get('id') + ' for ' + data.id)

            room = channel.get("name")
            targetClientSocket = channel.call[data.id]

            # convey our ice_candidates to the client in question, if he's still in the channel
            if targetClientSocket?
                targetClientSocket.in(room).emit("ice_candidate:#{room}", {
                    label: data.label,
                    candidate: data.candidate,
                    id: client.get('id')
                })

        "offer": (namespace, socket, channel, client, data) ->
            DEBUG && console.log('Offer recieved from ' + client.get('id') + ' for ' + data.id)

            room = channel.get("name")
            targetClientSocket = channel.call[data.id]

            if targetClientSocket?

                targetClientSocket.in(room).emit("offer:#{room}",{
                    sdp: data.sdp,
                    id: client.get('id')
                })

        "answer": (namespace, socket, channel, client, data) ->
            DEBUG && console.log('Answer recieved from ' + client.get('id') + ' for ' + data.id)

            room = channel.get("name")
            targetClientSocket = channel.call[data.id]

            if targetClientSocket?
                targetClientSocket.in(room).emit "answer:#{room}",
                    sdp: data.sdp,
                    id: client.get('id')

        "update": (namespace, socket, channel, client, data) ->
            room = channel.get('name')
            socket.emit "status:#{room}", active: !_.isEmpty(channel.call)
