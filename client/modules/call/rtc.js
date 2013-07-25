//Based on https://github.com/webRTC/webrtc.io-client/blob/master/lib/webrtc.io.js
//CLIENT

// Fallbacks for vendor-specific variables until the spec is finalized.

var PeerConnection = window.PeerConnection = (window.PeerConnection || window.webkitPeerConnection00 || window.webkitRTCPeerConnection || window.mozRTCPeerConnection);
var URL = window.URL = (window.URL || window.webkitURL || window.msURL || window.oURL);
var getUserMedia = navigator.getUserMedia = (navigator.getUserMedia || navigator.webkitGetUserMedia || navigator.mozGetUserMedia || navigator.msGetUserMedia);
var nativeRTCIceCandidate = window.nativeRTCIceCandidate = (window.mozRTCIceCandidate || window.RTCIceCandidate);
var nativeRTCSessionDescription = window.nativeRTCSessionDescription  = (window.mozRTCSessionDescription || window.RTCSessionDescription); // order is very important: "RTCSessionDescription" defined in Nighly but useless

var sdpConstraints = {
    'mandatory': {
        'OfferToReceiveAudio': true,
        'OfferToReceiveVideo': true
    }
};

if (navigator.webkitGetUserMedia) {
    if (!webkitMediaStream.prototype.getVideoTracks) {
        webkitMediaStream.prototype.getVideoTracks = function() {
            return this.videoTracks;
        };
        webkitMediaStream.prototype.getAudioTracks = function() {
            return this.audioTracks;
        };
    }

    // New syntax of getXXXStreams method in M26.
    if (!webkitRTCPeerConnection.prototype.getLocalStreams) {
        webkitRTCPeerConnection.prototype.getLocalStreams = function() {
            return this.localStreams;
        };
        webkitRTCPeerConnection.prototype.getRemoteStreams = function() {
            return this.remoteStreams;
        };
    }
}

function preferOpus(sdp) {
    var sdpLines = sdp.split('\r\n');
    var mLineIndex = null;
    // Search for m line.
    for (var i = 0; i < sdpLines.length; i++) {
        if (sdpLines[i].search('m=audio') !== -1) {
            mLineIndex = i;
            break;
        }
    }
    if (mLineIndex === null) return sdp;

    // If Opus is available, set it as the default in m line.
    for (var j = 0; j < sdpLines.length; j++) {
        if (sdpLines[j].search('opus/48000') !== -1) {
            var opusPayload = extractSdp(sdpLines[j], /:(\d+) opus\/48000/i);
            if (opusPayload) sdpLines[mLineIndex] = setDefaultCodec(sdpLines[mLineIndex], opusPayload);
            break;
        }
    }

    // Remove CN in m line and sdp.
    sdpLines = removeCN(sdpLines, mLineIndex);

    sdp = sdpLines.join('\r\n');
    return sdp;
}

function extractSdp(sdpLine, pattern) {
    var result = sdpLine.match(pattern);
    return (result && result.length == 2) ? result[1] : null;
}

function setDefaultCodec(mLine, payload) {
    var elements = mLine.split(' ');
    var newLine = [];
    var index = 0;
    for (var i = 0; i < elements.length; i++) {
        if (index === 3) // Format of media starts from the fourth.
            newLine[index++] = payload; // Put target payload to the first.
        if (elements[i] !== payload) newLine[index++] = elements[i];
    }
    return newLine.join(' ');
}

function removeCN(sdpLines, mLineIndex) {
    var mLineElements = sdpLines[mLineIndex].split(' ');
    // Scan from end for the convenience of removing an item.
    for (var i = sdpLines.length - 1; i >= 0; i--) {
        var payload = extractSdp(sdpLines[i], /a=rtpmap:(\d+) CN\/\d+/i);
        if (payload) {
            var cnPos = mLineElements.indexOf(payload);
            if (cnPos !== -1) {
                // Remove CN payload from m line.
                mLineElements.splice(cnPos, 1);
            }
            // Remove CN line in sdp
            sdpLines.splice(i, 1);
        }
    }

    sdpLines[mLineIndex] = mLineElements.join(' ');
    return sdpLines;
}

function mergeConstraints(cons1, cons2) {
    var merged = cons1;
    for (var name in cons2.mandatory) {
        merged.mandatory[name] = cons2.mandatory[name];
    }
    merged.optional.concat(cons2.optional);
    return merged;
}

define(['underscore'], function(_) {
    return function() {

        var rtc = this;
        // Toggle debug mode (console.log)
        this.debug = false;

        // Holds a connection to the server.
        this._socket = null;

        // Holds identity for the client.
        this._me = null;
        this.connected = false;

        this.socketEvents = {};

        // Holds callbacks for certain events.
        this._events = {};

        this.on = function(eventName, callback) {
            rtc._events[eventName] = rtc._events[eventName] || [];
            rtc._events[eventName].push(callback);
        };

        this.fire = function(eventName, _) {
            var events = rtc._events[eventName];
            var args = Array.prototype.slice.call(arguments, 1);

            if (!events) {
                return;
            }

            for (var i = 0, len = events.length; i < len; i++) {
                events[i].apply(null, args);
            }
        };
        this.on('ready', function() {
            rtc.createPeerConnections();
            rtc.addStreams();
            rtc.addDataChannels();
            rtc.sendOffers();
            rtc.offerSent = true;
        });

        // Holds the STUN/ICE server to use for PeerConnections.
        this.SERVER = function() {
            if (navigator.mozGetUserMedia) {
                return {
                    "iceServers": [{
                        "url": "stun:23.21.150.121"
                    }]
                };
            }
            return {
                "iceServers": [{
                    "url": "stun:stun.l.google.com:19302"
                }]
            };
        };

        this.listen = function(socket, room) {
            rtc._room = room;
            rtc._socket = socket;
            rtc.socketEvents = {
                "peers": function(data) {
                    console.log('recieved peers');
                    rtc.connections = data.connections;
                    rtc._me = data.you;
                    if (rtc.offerSent) { // 'ready' was fired before 'get_peers'
                        rtc.createPeerConnections();
                        rtc.addStreams();
                        rtc.addDataChannels();
                        rtc.sendOffers();
                    }
                    // fire connections event and partc.offerSentss peers
                    rtc.fire('connections', rtc.connections);
                },
                "ice_candidate": function(data) {

                    console.log('recieved ICE');
                    var candidate = new nativeRTCIceCandidate(data);
                    rtc.peerConnections[data.id].addIceCandidate(candidate);
                    rtc.fire('receive ice candidate', candidate);
                },

                "new_peer": function(data) {

                    console.log('New Peer');
                    var id = data.id;
                    rtc.connections.push(id);
                    delete rtc.offerSent;

                    var pc = rtc.createPeerConnection(id);
                    for (var i = 0; i < rtc.streams.length; i++) {
                        var stream = rtc.streams[i];
                        pc.addStream(stream);
                    }
                },

                "remove_peer": function(data) {
                    console.log('peer left');
                    var id = data.id;
                    rtc.fire('disconnect stream', id);
                    if (typeof(rtc.peerConnections[id]) !== 'undefined')
                        rtc.peerConnections[id].close();
                    delete rtc.peerConnections[id];
                    delete rtc.dataChannels[id];
                    delete rtc.connections[_.indexOf(rtc.connections, id)];
                },

                "offer": function(data) {

                    console.log('recieved Offer');
                    rtc.receiveOffer(data.id, data.sdp);
                    rtc.fire('receive offer', data);
                },
                "answer": function(data) {

                    console.log('recieved Answer');
                    rtc.receiveAnswer(data.id, data.sdp);
                    rtc.fire('receive answer', data);
                }
            };
            _.each(rtc.socketEvents, function(value, key) {
                // listen to a subset of event
                socket.on(key + ":" + room, value);
            });
        };


        // Reference to the lone PeerConnection instance.
        this.peerConnections = {};

        // Array of known peer socket ids
        this.connections = [];
        // Stream-related variables.
        this.streams = [];
        this.numStreams = 0;
        this.initializedStreams = 0;


        // Reference to the data channels
        this.dataChannels = {};

        // PeerConnection datachannel configuration
        this.dataChannelConfig = {
            "optional": [{
                "RtpDataChannels": true
            }, {
                "DtlsSrtpKeyAgreement": true
            }]
        };

        this.pc_constraints = {
            "optional": [{
                "DtlsSrtpKeyAgreement": true
            }]
        };


        // check whether data channel is supported.
        this.checkDataChannelSupport = function() {
            try {
                // raises exception if createDataChannel is not supported
                var pc = new PeerConnection(rtc.SERVER(), rtc.dataChannelConfig);
                var channel = pc.createDataChannel('supportCheck', {
                    reliable: false
                });
                channel.close();
                return true;
            } catch (e) {
                return false;
            }
        };

        this.dataChannelSupport = this.checkDataChannelSupport();


        /**
         * Connects to the websocket server.
         */
        this.connect = function() {
            rtc._socket.emit('join:' + rtc._room, {}, function() {
                rtc.fire('post join');
            });
            this.connected = true;
        };

        this.disconnect = function() {
            rtc._socket.emit('leave:' + rtc._room, {});
            _.each(rtc.socketEvents, function(method, key) {
                rtc._socket.removeAllListeners(key + ":" + self.channelName);
            });
            _.each(rtc.peerConnections, function(connection, key) {
                connection.close();
                rtc.fire('disconnect stream', key);
            });

            rtc.streams = [];
            rtc.peerConnections = {};
            rtc.dataChannels = {};
            rtc.connections = [];
            rtc.fire('disconnect');
            this.connected = false;
        };


        this.sendOffers = function() {
            console.log('Sending offers');
            for (var i = 0, len = rtc.connections.length; i < len; i++) {
                var socketId = rtc.connections[i];
                rtc.sendOffer(socketId);
            }
        };

        this.onClose = function(data) {
            rtc.on('close_stream', function() {
                rtc.fire('close_stream', data);
            });
        };

        this.createPeerConnections = function() {
            for (var i = 0; i < rtc.connections.length; i++) {
                rtc.createPeerConnection(rtc.connections[i]);
            }
        };

        this.createPeerConnection = function(id) {

            var config = rtc.pc_constraints;
            if (rtc.dataChannelSupport) config = rtc.dataChannelConfig;

            var pc = rtc.peerConnections[id] = new PeerConnection(rtc.SERVER(), config);
            pc.onicecandidate = function(event) {
                if (event.candidate) {
                    rtc._socket.emit("ice_candidate:" + rtc._room, {
                        "label": event.candidate.sdpMLineIndex,
                        "candidate": event.candidate.candidate,
                        "id": id
                    });
                }
                rtc.fire('ice candidate', event.candidate);
            };

            pc.onopen = function() {
                // TODO: Finalize this API
                console.log('stream opened');
                rtc.fire('peer connection opened');
            };

            pc.onaddstream = function(event) {
                // TODO: Finalize this API
                console.log('remote stream added');
                rtc.fire('add remote stream', event.stream, id);
            };

            if (rtc.dataChannelSupport) {
                pc.ondatachannel = function(evt) {
                    if (rtc.debug) console.log('data channel connecting ' + id);
                    rtc.addDataChannel(id, evt.channel);
                };
            }

            return pc;
        };

        this.sendOffer = function(socketId) {
            var pc = rtc.peerConnections[socketId];

            var constraints = {
                "optional": [],
                "mandatory": {
                    "MozDontOfferDataChannel": true
                }
            };
            // temporary measure to remove Moz* constraints in Chrome
            if (navigator.webkitGetUserMedia) {
                for (var prop in constraints.mandatory) {
                    if (prop.indexOf("Moz") != -1) {
                        delete constraints.mandatory[prop];
                    }
                }
            }
            constraints = mergeConstraints(constraints, sdpConstraints);

            pc.createOffer(function(session_description) {
                session_description.sdp = preferOpus(session_description.sdp);
                pc.setLocalDescription(session_description);
                rtc._socket.emit("offer:" + rtc._room, {
                    "id": socketId,
                    "sdp": session_description
                });
            }, null, sdpConstraints);
        };

        this.receiveOffer = function(socketId, sdp) {
            var pc = rtc.peerConnections[socketId];
            rtc.sendAnswer(socketId, sdp);
        };

        this.sendAnswer = function(socketId, sdp) {
            var pc = rtc.peerConnections[socketId];
            pc.setRemoteDescription(new nativeRTCSessionDescription(sdp));
            pc.createAnswer(function(session_description) {
                pc.setLocalDescription(session_description);
                rtc._socket.emit("answer:" + rtc._room, {
                    "id": socketId,
                    "sdp": session_description
                });
                //TODO Unused variable!?
                var offer = pc.remoteDescription;
            }, null, sdpConstraints);
        };


        this.receiveAnswer = function(socketId, sdp) {
            var pc = rtc.peerConnections[socketId];
            pc.setRemoteDescription(new nativeRTCSessionDescription(sdp));
        };


        this.createStream = function(opt, onSuccess, onFail) {
            var options;
            onSuccess = onSuccess || function() {};
            onFail = onFail || function() {};

            options = {
                video: !! opt.video,
                audio: !! opt.audio
            };

            if (getUserMedia) {
                rtc.numStreams++;
                getUserMedia.call(navigator, options, function(stream) {
                    console.log(stream.getAudioTracks());
                    rtc.streams.push(stream);
                    rtc.initializedStreams++;
                    onSuccess(stream);
                    if (rtc.initializedStreams === rtc.numStreams) {
                        rtc.fire('ready');
                    }
                }, function(error) {
                    onFail(error, "Could not connect to stream");
                });
            }
        };

        this.muteAudio = function(){
            _.each(rtc.streams,function(stream){
                _.each(stream.getAudioTracks(),function(track){
                    track.enabled = false;
                });
            });
        };

        this.unmuteAudio = function(){
            _.each(rtc.streams,function(stream){
                _.each(stream.getAudioTracks(),function(track){
                    track.enabled = true;
                });
            });
        };

        this.muteVideo = function(){
            _.each(rtc.streams,function(stream){
                _.each(stream.getVideoTracks(),function(track){
                    track.enabled = false;
                });
            });
        };

        this.unmuteVideo = function(){
            _.each(rtc.streams,function(stream){
                _.each(stream.getVideoTracks(),function(track){
                    track.enabled = true;
                });
            });
        };

        this.addStreams = function() {
            for (var i = 0; i < rtc.streams.length; i++) {
                var stream = rtc.streams[i];
                for (var connection in rtc.peerConnections) {
                    rtc.peerConnections[connection].addStream(stream);
                }
            }
        };

        this.attachStream = function(stream, element) {
            if (typeof(element) === "string")
                element = document.getElementById(element);
            if (navigator.mozGetUserMedia) {
                if (rtc.debug) console.log("Attaching media stream");
                element.mozSrcObject = stream;
                element.play();
            } else {
                element.src = webkitURL.createObjectURL(stream);
            }
        };


        this.createDataChannel = function(pcOrId, label) {
            if (!rtc.dataChannelSupport) {
                //TODO this should be an exception
                alert('webRTC data channel is not yet supported in this browser,' +
                    ' or you must turn on experimental flags');
                return;
            }

            var id, pc;
            if (typeof(pcOrId) === 'string') {
                id = pcOrId;
                pc = rtc.peerConnections[pcOrId];
            } else {
                pc = pcOrId;
                id = undefined;
                for (var key in rtc.peerConnections) {
                    if (rtc.peerConnections[key] === pc) id = key;
                }
            }

            if (!id) throw new Error('attempt to createDataChannel with unknown id');

            if (!pc || !(pc instanceof PeerConnection)) throw new Error('attempt to createDataChannel without peerConnection');

            // need a label
            label = label || 'fileTransfer' || String(id);

            // chrome only supports reliable false atm.
            var options = {
                reliable: false
            };

            var channel;
            try {
                if (rtc.debug) console.log('createDataChannel ' + id);
                channel = pc.createDataChannel(label, options);
            } catch (error) {
                if (rtc.debug) console.log('seems that DataChannel is NOT actually supported!');
                throw error;
            }

            return rtc.addDataChannel(id, channel);
        };

        this.addDataChannel = function(id, channel) {

            channel.onopen = function() {
                if (rtc.debug) console.log('data stream open ' + id);
                rtc.fire('data stream open', channel);
            };

            channel.onclose = function(event) {
                delete rtc.dataChannels[id];
                delete rtc.peerConnections[id];
                delete rtc.connections[id];
                if (rtc.debug) console.log('data stream close ' + id);
                rtc.fire('data stream close', channel);
            };

            channel.onmessage = function(message) {
                if (rtc.debug) console.log('data stream message ' + id);
                rtc.fire('data stream data', channel, message.data);
            };

            channel.onerror = function(err) {
                if (rtc.debug) console.log('data stream error ' + id + ': ' + err);
                rtc.fire('data stream error', channel, err);
            };

            // track dataChannel
            rtc.dataChannels[id] = channel;
            return channel;
        };

        this.addDataChannels = function() {
            if (!rtc.dataChannelSupport) return;

            for (var connection in rtc.peerConnections)
                rtc.createDataChannel(connection);
        };
        return this;
    };
});
