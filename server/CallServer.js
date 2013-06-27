exports.CallServer = function (sio, redisC, EventBus, Channels, ChannelModel) {
    var CALLSPACE = "/call",
        config = require('./config.js').Configuration,
        Client = require('../client/client.js').ClientModel,
        Clients = require('../client/client.js').ClientsCollection,
        _ = require('underscore');

    var DEBUG = config.DEBUG;
    var CallServer = require('./AbstractServer.js').AbstractServer(sio, redisC, EventBus, Channels, ChannelModel);
    var rtc = {
        clients: {}
    };
    CallServer.initialize({
        name: "CallServer",
        SERVER_NAMESPACE: CALLSPACE,
        events: {
            "leave": function (namespace, socket, channel, client, data) {
                var room = channel.get("name");
                socket.in(room).broadcast.emit("remove_peer_connected:"+room,{
                    id: client.get("id")
                });
            },
            "send_ice_candidate": function(namespace, socket, channel, client, data){
                var room = channel.get("name");
                var targetClient = rtc.clients[data.id];
                if (typeof targetClient !== "undefined") {
                    targetClient.in(room).emit("recieve_ice_candidate:"+room,{
                        label: data.label,
                        candidate: data.candidate,
                        id: client.get('id')
                    });
                }
            },
            "send_offer": function(namespace, socket, channel, client, data){
                var room = channel.get("name");
                var targetClient = rtc.clients[data.id];
                if (targetClient) {
                    targetClient.in(room).emit("recieve_offer:" + room,{
                        sdp: data.sdp,
                        id: client.get('id')
                    });
                }
            },
            "send_answer": function(namespace, socket, channel, client, data){
                var targetClient = rtc.clients[data.id];
                var room = channel.get("name");
                if (targetClient) {
                    targetClient.in(room).emit("recieve_answer:"+room,{
                        sdp: data.sdp,
                        id: client.get('id')
                    });
                }
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
            console.log("CallServer client connected");
            var room = channel.get("name");
            //Store the reference to the socket, sicn
            rtc.clients[client.get('id')] = socket;
            socket.in(room).broadcast.emit("new_peer_connected:"+room,{
                id: client.get('id')
            });
            // send new peer a list of all prior peers
            socket.in(room).emit("get_peers:"+room,{
                "connections": _.without(_.keys(rtc.clients),client.get('id')),
                "you": client.get('id')
            });
        }
    });


};