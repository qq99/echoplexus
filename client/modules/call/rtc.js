/*global window:false */
/*global navigator:false */

//Based on https://github.com/webRTC/webrtc.io-client/blob/master/lib/webrtc.io.js

// Fallbacks for vendor-specific variables until the spec is finalized.
var PeerConnection = window.PeerConnection = (window.PeerConnection || window.webkitPeerConnection00 || window.webkitRTCPeerConnection || window.mozRTCPeerConnection);
var URL = window.URL = (window.URL || window.webkitURL || window.msURL || window.oURL);
var getUserMedia = navigator.getUserMedia = (navigator.getUserMedia || navigator.webkitGetUserMedia || navigator.mozGetUserMedia || navigator.msGetUserMedia);
var NativeRTCIceCandidate = window.NativeRTCIceCandidate = (window.mozRTCIceCandidate || window.RTCIceCandidate);
var NativeRTCSessionDescription = window.NativeRTCSessionDescription  = (window.mozRTCSessionDescription || window.RTCSessionDescription); // order is very important: "RTCSessionDescription" defined in Nighly but useless

// always offer to receive both types of media, regardless of whether we send them
var sdpConstraints = {
	"optional": [],
	'mandatory': {
		'OfferToReceiveAudio': true,
		'OfferToReceiveVideo': true
	}
};

var pcDataChannelConfig = {
	"optional": [{"RtpDataChannels": true}, {"DtlsSrtpKeyAgreement": true}]
};
var pcConfig = {
	"optional": [{"DtlsSrtpKeyAgreement": true}]
};

// check whether data channel is supported:
var supportsDataChannel = (function () {
	try {
		// raises exception if createDataChannel is not supported
		var pc = new PeerConnection(stunIceConfig(), pcDataChannelConfig);
		var channel = pc.createDataChannel('supportCheck', {
			reliable: false
		});
		channel.close();
		return true;
	} catch (e) {
		return false;
	}
})();

// create a polyfilled config for the PeerConnection polyfill object, using google's STUN servers
function stunIceConfig() {
	// config objects
	var _ff_peerConnectionConfig = {
		"iceServers": [{
			"url": "stun:23.21.150.121"
		}]
	};
	var _chrome_peerConnectionConfig = {
		"iceServers": [{
			"url": "stun:stun.l.google.com:19302"
		}]
	};

	// ua detection
	if (ua.firefox) {
		return _ff_peerConnectionConfig;
	} else {
		return _chrome_peerConnectionConfig;
	}
}

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
	var RTC = Backbone.Model.extend({
		defaults: {
			me: null, // my socket id
			connected: false
		},
		initialize: function (opts) {
			var self = this;

			_.bindAll(this);

			_.extend(this, opts);

			this.peerConnections = {};
			this.localStreams = [];
			this.peerIDs = [];
			// this.dataChannels = {};
		},
		listen: function () {
			var self = this,
				room = this.room,
				socket = this.socket;

			this.socketEvents = {
				"ice_candidate": function (data) {
					// console.log('received signal: ice_candidate', data);
					var candidate = new NativeRTCIceCandidate(data);
					self.peerConnections[data.id].addIceCandidate(candidate);
				},

				"new_peer": function (data) {
					console.log('signal: new_peer', data);

					var id = data.id,
						pc = self.createPeerConnection(id);

					self.peerIDs.push(id);
					self.peerIDs = _.uniq(self.peerIDs); // just in case...

					// extend a welcome arm to our new peer <3
					self.sendOffer(id);
				},

				"remove_peer": function (data) {
					console.log('signal: remove_peer', data);

					var id = data.id;

					self.trigger('disconnected_stream', id);
					if (typeof(self.peerConnections[id]) !== 'undefined') {
						self.peerConnections[id].close();
					}

					delete self.peerConnections[id];
					// delete self.dataChannels[id];
					delete self.peerIDs[_.indexOf(this.peerIDs, id)];
				},

				"offer": function(data) {

					console.log('recieved Offer');
					self.receiveOffer(data.id, data.sdp);
				},
				"answer": function(data) {

					console.log('recieved Answer');
					self.receiveAnswer(data.id, data.sdp);
				}
			};

			_.each(this.socketEvents, function(value, key) {
				// listen to a subset of event
				socket.on(key + ":" + room, value);
			});
		},
		startSignalling: function () {
			var self = this;
			// attempt to register our intent to join/start call with the signalling server
			this.socket.emit('join:' + this.get("room"), {}, function (ack) {
				self.set({
					me: ack.you,
					connected: true
				});
				self.connections = ack.connections;
			});
		},
		disconnect: function () {
			var self = this;

			this.socket.emit('leave:' + this.get("room"), {});

			// remove all signalling socket listeners
			_.each(this.socketEvents, function (method, key) {
				self.socket.removeAllListeners(key + ":" + self.room);
			});

			_.each(self.peerConnections, function(connection, key) {
				connection.close();
				self.trigger('disconnected_stream', key);
			});

			this.localStreams = [];
			this.peerConnections = {};
			this.dataChannels = {};
			this.set({
				connected: false,
				me: null
			});
		},

		sendOffers: function () {

			for (var i = 0, len = this.peerIDs.length; i < len; i++) {
				var socketId = this.peerIDs[i];
				this.sendOffer(socketId);
			}
		},

		createPeerConnection: function (targetClientID) {
			var self = this,
				room = this.get("room");

			if (typeof this.peerConnections[targetClientID] !== "undefined") { // don't create it twice!
				console.warn("Tried to create a peer connection, but we already had one for this target client.  This is probably a latent bug.");
				return;
			}

			var pc = this.peerConnections[targetClientID] = new PeerConnection(stunIceConfig(), pcConfig);

			// when we learn about our own ice candidates
			pc.onicecandidate = function(event) {
				if (event.candidate) {
					self.socket.emit("ice_candidate:" + room, {
						"label": event.candidate.sdpMLineIndex,
						"candidate": event.candidate.candidate,
						"id": targetClientID
					});
				}
			};

			pc.onopen = function() {
				console.log('stream opened');
			};

			pc.onaddstream = function(event) {
				console.log('remote stream added', targetClientID);
				self.trigger('added_remote_stream', {
					stream: event.stream,
					socketID: targetClientID
				});
			};

/*
			if (rtc.dataChannelSupport) {
				pc.ondatachannel = function(evt) {
					if (rtc.debug) console.log('data channel connecting ' + targetClientID);
					rtc.addDataChannel(targetClientID, evt.channel);
				};
			}
*/

			return pc;
		},

		createPeerConnections: function () {
			var self = this;

			_.each(this.peerIDs, function (connection) {
				self.createPeerConnection(connection);
			});
		},

		sendOffer: function (socketId) {
			console.log('Sending offers to ', socketId);
			var pc = this.peerConnections[socketId],
				room = this.get("room"),
				self = this;

			_.each(self.localStreams, function (stream) {
				pc.addStream(stream);
			});

			pc.createOffer(function (description) {
				// description.sdp = preferOpus(description.sdp); // alter sdp
				pc.setLocalDescription(description);
				// let the target client's socket know our SDP offering
				self.socket.emit("offer:" + room, {
					"id": socketId,
					"sdp": description
				});
			}, function (err) {
				console.error(err);
			}, sdpConstraints);
		},

		receiveOffer: function (socketId, sdp) {
			var self = this,
				pc = this.createPeerConnection(socketId);

			_.each(this.localStreams, function (stream) {
				pc.addStream(stream);
			});

			pc.setRemoteDescription(new NativeRTCSessionDescription(sdp));
			pc.createAnswer(function(session_description) {
				pc.setLocalDescription(session_description);
				self.socket.emit("answer:" + self.get("room"), {
					"id": socketId,
					"sdp": session_description
				});
			}, function (err) {
				console.error(err);
			}, sdpConstraints);
		},

		receiveAnswer: function (socketId, sdp) {
			var pc = this.peerConnections[socketId];
			pc.setRemoteDescription(new NativeRTCSessionDescription(sdp));
		},

		requestClientStream: function (opt, onSuccess, onFail) {
			var self = this,
				options;

			onSuccess = onSuccess || function() {};
			onFail = onFail || function() {};

			options = {
				video: !! opt.video,
				audio: !! opt.audio
			};

			if (getUserMedia) {
				getUserMedia.call(navigator, options, function (stream) {
					self.localStreams.push(stream);
					onSuccess(stream);
				}, function(error) {
					onFail(error, "Could not connect to stream");
				});
			} else {
				onFail(null, "Your browser does not appear to support getUserMedia");
			}
		},

		addLocalStreamsToRemote: function() {
			var self = this,
				streams = this.localStreams,
				pcs = this.peerConnections;

			_.each(pcs, function (pc, peer_id) {
				_.each(streams, function (stream) {
					pc.addStream(stream);
				});
			});
		},

		attachStream: function(stream, element) {
			// element can be a dom element or a dom ele's ID
			if (typeof(element) === "string") {
				element = document.getElementById(element);
			}

			if (ua.firefox) {
				element.mozSrcObject = stream;
				element.play();
			} else {
				element.src = webkitURL.createObjectURL(stream);
			}
		},

		setUserMedia: function (opts) {
			_.each(this.localStreams, function (stream) {
				if (typeof opts.video !== "undefined") {
					_.each(stream.getVideoTracks(), function (track){
						track.enabled = opts.video;
					});
				}

				if (typeof opts.audio !== "undefined") {
					_.each(stream.getAudioTracks(), function (track){
						track.enabled = opts.audio;
					});
				}
			});
		},

		// createDataChannel: function(pcOrId, label) {
		// 	if (!this.dataChannelSupport) {
		// 		//TODO this should be an exception
		// 		alert('webRTC data channel is not yet supported in this browser,' +
		// 			' or you must turn on experimental flags');
		// 		return;
		// 	}

		// 	var id, pc;
		// 	if (typeof(pcOrId) === 'string') {
		// 		id = pcOrId;
		// 		pc = rtc.peerConnections[pcOrId];
		// 	} else {
		// 		pc = pcOrId;
		// 		id = undefined;
		// 		for (var key in rtc.peerConnections) {
		// 			if (rtc.peerConnections[key] === pc) id = key;
		// 		}
		// 	}

		// 	if (!id) throw new Error('attempt to createDataChannel with unknown id');

		// 	if (!pc || !(pc instanceof PeerConnection)) throw new Error('attempt to createDataChannel without peerConnection');

		// 	// need a label
		// 	label = label || 'fileTransfer' || String(id);

		// 	// chrome only supports reliable false atm.
		// 	var options = {
		// 		reliable: false
		// 	};

		// 	var channel;
		// 	try {
		// 		if (rtc.debug) console.log('createDataChannel ' + id);
		// 		channel = pc.createDataChannel(label, options);
		// 	} catch (error) {
		// 		if (rtc.debug) console.log('seems that DataChannel is NOT actually supported!');
		// 		throw error;
		// 	}

		// 	return rtc.addDataChannel(id, channel);
		// },

		// addDataChannel: function (id, channel) {
		// 	return;
		// 	channel.onopen = function() {
		// 		if (rtc.debug) console.log('data stream open ' + id);
		// 		rtc.fire('data stream open', channel);
		// 	};

		// 	channel.onclose = function(event) {
		// 		delete rtc.dataChannels[id];
		// 		delete rtc.peerConnections[id];
		// 		delete rtc.peerIDs[id];
		// 		if (rtc.debug) console.log('data stream close ' + id);
		// 		rtc.fire('data stream close', channel);
		// 	};

		// 	channel.onmessage = function(message) {
		// 		if (rtc.debug) console.log('data stream message ' + id);
		// 		rtc.fire('data stream data', channel, message.data);
		// 	};

		// 	channel.onerror = function(err) {
		// 		if (rtc.debug) console.log('data stream error ' + id + ': ' + err);
		// 		rtc.fire('data stream error', channel, err);
		// 	};

		// 	// track dataChannel
		// 	rtc.dataChannels[id] = channel;
		// 	return channel;
		// },

		// addDataChannels: function () {
		// 	if (!rtc.dataChannelSupport) return;

		// 	for (var connection in rtc.peerConnections) {
		// 		rtc.createDataChannel(connection);
		// 	}
		// }
	});

	return RTC;
});