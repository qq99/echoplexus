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
            "join": function(namespace,socket,channel,client,data){
                var room = channel.get("name");
                if(_.isEmpty(channel.call)) {
                    var status = {"active":true};
                    socket.in(room).broadcast.emit("status:"+room,status);
                    socket.in(room).emit("status:"+room,status);
                }
                channel.call[client.get('id')] = socket;
                socket.in(room).broadcast.emit("new_peer:"+room,{
                    id: client.get('id')
                });
                // send new peer a list of all prior peers
                socket.in(room).emit("peers:"+room,{
                    "connections": _.without(_.keys(channel.call),client.get('id')),
                    "you": client.get('id')
                });
            },
            "leave": function (namespace, socket, channel, client, data) {
                var room = channel.get("name");
                socket.in(room).broadcast.emit("remove_peer:"+room,{
                    id: client.get("id")
                });
                delete channel.call[client.get('id')];
                if(_.isEmpty(channel.call)) {
                    var status = {"active":false};
                    socket.in(room).broadcast.emit("status:"+room,status);
                    socket.in(room).emit("status:"+room,status);
                }
            },
            "ice_candidate": function(namespace, socket, channel, client, data){
                var room = channel.get("name");
                var targetClient = channel.call[data.id];
                if (typeof targetClient !== "undefined") {
                    targetClient.in(room).emit("ice_candidate:"+room,{
                        label: data.label,
                        candidate: data.candidate,
                        id: client.get('id')
                    });
                }
            },
            "offer": function(namespace, socket, channel, client, data){
                var room = channel.get("name");
                var targetClient = channel.call[data.id];
                if (targetClient) {
                    targetClient.in(room).emit("offer:" + room,{
                        sdp: data.sdp,
                        id: client.get('id')
                    });
                }
            },
            "answer": function(namespace, socket, channel, client, data){
                var targetClient = channel.call[data.id];
                var room = channel.get("name");
                if (targetClient) {
                    targetClient.in(room).emit("answer:"+room,{
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