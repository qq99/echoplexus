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
            "close": function (namespace, socket, channel, client, data) {
                var room = channel.get("name");
                socket.in(room).broadcast.emit("remove_peer_connected",{
                    id: client.get("id")
                });
            },
            "send_ice_candidate": function(namespace, socket, channel, client, data){
                var targetClients = channel.clients.where({id: data.id});
                //var soc = rtc.getSocket(data.socketId);
                if (typeof targetClients !== "undefined" &&
                        targetClients.length) {
                    _.each(targetClients,function(cli){
                        cli.socketRef.emit("recieve_ice_candidate",{
                            label: data.label,
                            candidate: data.candidate,
                            id: client.get('id')
                        })
                    });
                }
            },
            "send_offer": function(namespace, socket, channel, client, data){
                var targetClients = channel.clients.where({id: data.id});
                if (typeof targetClients !== "undefined" &&
                        targetClients.length) {
                    _.each(targetClients,function(cli){
                        cli.socketRef.emit("recieve_offer",{
                            sdp: data.sdp,
                            id: client.get('id')
                        });
                    });
                }
            },
            "send_answer": function(namespace, socket, channel, client, data){
                var targetClients = channel.clients.where({id: data.id});
                if (typeof targetClients !== "undefined" &&
                        targetClients.length) {
                    _.each(targetClients,function(cli){
                        cli.socketRef.emit("recieve_answer",{
                            sdp: data.sdp,
                            id: client.get('id')
                        });
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
            socket.in(room).broadcast.emit("new_peer_connected",{
                id: client.get('id')
            });
            // send new peer a list of all prior peers
            socket.in(room).emit("get_peers",{
                //"connections": channel.clients.,
                "you": client.get('id')
            });
        }
    });


};