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
                DEBUG && console.log('Client joined');
                var room = channel.get("name");
                if(channel.call.roomdata)
                    socket.in(room).emit("negotiate:"+room,channel.call.roomdata);
                // _.each(_.without(_.keys(channel.call.participants),channel.call.roomdata.userid,client.get('id')),function(key){
                //     channel.call.participants[key].emit("negotiate:"+ room,{
                //         participationRequest: true,
                //         to: key,
                //         userid: client.get('id')
                //     });
                // });
            },
            "negotiate": function(namespace, socket, channel, client, data){
                var room = channel.get('name');
                if (data.participationRequest || data.roomid)
                {
                    if(data.roomid) channel.call.roomdata = data;
                    if(_.isEmpty(channel.call.participants)) {
                        var status = {"active":true};
                        socket.in(room).broadcast.emit("status:"+room,status);
                        socket.in(room).emit("status:"+room,status);
                    }

                    channel.call.participants[client.get('id')] = socket;
                } else if (data.leaving){
                    delete channel.call.participants[client.get('id')];
                    if(_.isEmpty(channel.call.participants)) {
                        var status = {"active":true};
                        socket.in(room).broadcast.emit("status:"+room,status);
                        socket.in(room).emit("status:"+room,status);
                    }
                }
                if (!!data.to && !!channel.call.participants[data.to]) 
                    channel.call.participants[data.to].in(room).emit("negotiate:" + room, data);
                else socket.in(room).broadcast.emit("negotiate:" + room,data);

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
            socket.in(room).emit("status:"+room,{
                "active": !_.isEmpty(channel.call.participants)
            });
            socket.in(room).emit("your_id:"+room,{
                "id": client.get('id')
            });
            
        }
    });


};