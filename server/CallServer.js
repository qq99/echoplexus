exports.CallServer = function (sio, redisC, EventBus, Channels, ChannelModel) {
    var CALLSPACE = "/call",
        config = require('./config.js').Configuration,
        Client = require('../client/client.js').ClientModel,
        Clients = require('../client/client.js').ClientsCollection,
        _ = require('underscore');

    var DEBUG = config.DEBUG;
    var CallServer = require('./AbstractServer.js').AbstractServer(sio, redisC, EventBus, Channels, ChannelModel);

    CallServer.initialize({
        name: "CallServer",
        SERVER_NAMESPACE: CALLSPACE,
        events: {
            "join": function (namespace, socket, channel, client, data, ack) {
                DEBUG && console.log('client expressed interest in joining the call');

                var room = channel.get("name"),
                    clientID = client.get("id");

                // if this is the first person joining the call, announce the call as in progress
                if(_.isEmpty(channel.call)) {
                    sio.of(CALLSPACE).in(room).emit("status:" + room, {
                        "active": true
                    });
                }

                // add client to our memory
                channel.call[clientID] = socket;

                // send all other peers the new peer
                socket.in(room).broadcast.emit("new_peer:" + room, {
                    id: clientID
                });

                // send new peer a list of all prior peers' IDs and his own ID
                ack({
                   "connections": _.without(_.keys(channel.call),client.get('id')),
                    "you": clientID
                });
            },
            "leave": function (namespace, socket, channel, client, data) {
                var room = channel.get("name"),
                    clientID = client.get("id");

                // let all others know that this client has left
                socket.in(room).broadcast.emit("remove_peer:" + room, {
                    id: clientID
                });

                // remove this client from our memory
                delete channel.call[clientID];

                // if the last person has left, the call status is false (no call in progress)
                if(_.isEmpty(channel.call)) {
                    sio.of(CALLSPACE).in(room).emit("status:" + room, {
                        active: false
                    });
                }

                DEBUG && console.log("Client left, remaining: ", _.keys(channel.call).length);
            },
            "ice_candidate": function(namespace, socket, channel, client, data) {
                DEBUG && console.log('Ice Candidate recieved from ' + client.get('id') + ' for ' + data.id);

                var room = channel.get("name"),
                    targetClientSocket = channel.call[data.id];

                // convey our ice_candidates to the client in question, if he's still in the channel
                if (typeof targetClientSocket !== "undefined") {

                    targetClientSocket.in(room).emit("ice_candidate:" + room, {
                        label: data.label,
                        candidate: data.candidate,
                        id: client.get('id')
                    });
                }
            },
            "offer": function(namespace, socket, channel, client, data) {
                DEBUG && console.log('Offer recieved from ' + client.get('id') + ' for ' + data.id);

                var room = channel.get("name"),
                    targetClientSocket = channel.call[data.id];

                if (targetClientSocket) {

                    targetClientSocket.in(room).emit("offer:" + room,{
                        sdp: data.sdp,
                        id: client.get('id')
                    });
                }
            },
            "answer": function(namespace, socket, channel, client, data){
                DEBUG && console.log('Answer recieved from ' + client.get('id') + ' for ' + data.id);

                var room = channel.get("name"),
                    targetClientSocket = channel.call[data.id];

                if (targetClientSocket) {
                    targetClientSocket.in(room).emit("answer:" + room, {
                        sdp: data.sdp,
                        id: client.get('id')
                    });
                }
            },
            "update": function(namespace, socket, channel, client, data){
                var room = channel.get('name');
                socket.emit("status:"+room,{
                    "active": !_.isEmpty(channel.call)
                });
            }
        }
    });

    CallServer.start({
        error: function (err, socket, channel, client) {
            if (err) {
                console.log("CallServer: ", err);
                return;
            }
        },
        success: function (namespace, socket, channel, client) {
            var room = channel.get('name');
            socket.emit("status:"+room,{
                "active": !_.isEmpty(channel.call)
            });
        }
    });


};