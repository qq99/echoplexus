define(['modules/call/rtc',
        'text!modules/call/templates/callPanel.html',
        'text!modules/call/templates/mediaStreamContainer.html'
        ], function (RTC, callPanelTemplate, mediaStreamContainerTemplate) {
    return Backbone.View.extend({
        className: 'callClient',
        template: _.template(callPanelTemplate),
        streamTemplate: _.template(mediaStreamContainerTemplate),

        events: {
            "click .join": "joinCall",
            "click .hang-up": "leaveCall",
            "click .mute-audio": "toggleMuteAudio",
            "click .mute-video": "toggleMuteVideo"
        },

        initialize: function (opts) {
            var self = this;
            _.bindAll(this);
            this.channel = opts.channel;
            this.channelName = opts.room;
            this.config = opts.config;
            this.module = opts.module;
            this.socket = io.connect(this.config.host + "/call");
            this.rtc = new RTC({
                socket: this.socket,
                room: this.channelName
            });
            this.videos = {};
            this.render();

            this.on("show", function () {
                DEBUG && console.log("call_client:show");
                self.$el.show();
            });

            this.on("hide", function () {
                DEBUG && console.log("call_client:hide");
                self.$el.hide();
            });
            this.listen();

            if (!window.PeerConnection ||
                !navigator.getUserMedia) {
                $(".webrtc-error .no-webrtc", this.$el).show();
            }else {
                $(".webrtc-error .no-webrtc", this.$el).hide();
            }

            this.socket.emit('subscribe',{
                room: this.channelName
            });

            this.onResize = _.debounce(this.subdivideVideos, 250);
            $(window).on("resize", this.onResize);
        },

        toggleMuteAudio: function (ev) {
            var $this = $(ev.currentTarget);
            console.log('Muting audio');
            if ($this.hasClass("unmuted")) {
                this.rtc.setUserMedia({audio: false});
            } else {
                this.rtc.setUserMedia({audio: true});
            }
            $this.toggleClass("unmuted");
        },

        toggleMuteVideo: function (ev) {
            var $this = $(ev.currentTarget);

            if ($this.hasClass("unmuted")) {
                this.rtc.setUserMedia({video: false});
            } else {
                this.rtc.setUserMedia({video: true});
            }
            $this.toggleClass("unmuted");
        },

        showError: function (err, errMsg) {
            $(".no-call, .in-call", this.$el).hide();
            $(".webrtc-error, .reason.generic", this.$el).show();

            $(".reason.generic", this.$el).html("");
            $(".reason.generic", this.$el).append("<p>WebRTC failed!</p>");
            $(".reason.generic", this.$el).append("<p>" + errMsg + "</p>");
        },

        joinCall: function () {
            this.joiningCall = true;
            if (!this.$el.is(':visible')) return;

            console.log("Asking/Attempting to create client's local stream");

            // should this only create ONE local stream?
            // so that muting one mutes all..
            // probably should wrap it in a model if so so we can listen to it everywhere for UI purposes
            this.rtc.requestClientStream({
                "video": true,
                "audio": true
            }, this.gotUserMedia, this.showError);

        },

        gotUserMedia: function (stream) {
            var you = $('.you',this.$el).get(0);

            this.localStream = stream; // keep track of the stream we just made

            this.joiningCall = false;
            this.inCall = true;
            you.src = URL.createObjectURL(stream);
            // you.mozSrcObject = URL.createObjectURL(stream);
            you.play();
            $(".no-call", this.$el).hide();
            $(".in-call", this.$el).show();

            this.rtc.listen();
            this.rtc.startSignalling();
            this.rtc.setUserMedia({
                audio: true,
                video: true
            });

            window.events.trigger("in_call:" + this.channelName);
        },

        leaveCall: function () {
            this.inCall = false;

            $(".in-call", this.$el).hide();
            this.disconnect();
            $(".no-call", this.$el).show();
            this.showCallInProgress();

            window.events.trigger("left_call:" + this.channelName);
        },

        showCallInProgress: function () {
            $(".call-status", this.$el).hide();
            $(".no-call, .call-in-progress", this.$el).show();
        },

        showNoCallInProgress: function () {
            $(".call-status", this.$el).hide();
            $(".no-call, .no-call-in-progress", this.$el).show();
        },

        listen: function(){
            var self = this;
            // on peer joining the call:
            this.rtc.on('added_remote_stream', function (data) {
                console.log(self.channel);
                console.log("ADDING REMOTE STREAM...", data.stream, data.socketID);
                var $video = self.createVideoElement(data.socketID);

                self.rtc.attachStream(data.stream, $video.find("video")[0]);
                self.subdivideVideos();
            });
            // on peer leaving the call:
            this.rtc.on('disconnected_stream', function (clientID) {
                console.log('remove ' + clientID);
                self.removeVideo(clientID);
            });
            // politely hang up before closing the tab/window
            $(window).on("unload", function () {
                self.disconnect();
            });

            this.socketEvents = {
                "status": function(data){
                    if (data.active &&
                        !self.inCall &&
                        !self.joiningCall) {

                        // show the ringing phone if we're not in/joinin a call & a call starts
                        self.showCallInProgress();
                    } else if (!data.active) {
                        self.showNoCallInProgress();
                    }
                }
            };
            _.each(this.socketEvents, function (value, key) {
                // listen to a subset of event
                self.socket.on(key + ":" + self.channelName, value);
            });
        },
        disconnect: function(){
            $(".videos", this.$el).html("");
            if (this.localStream) {
                this.localStream.stop();
            }
            this.videos = [];
            this.rtc.setUserMedia({
                video: false,
                audio: false
            });
            this.rtc.disconnect();
        },
        kill: function(){
            var self = this;
            this.disconnect();
            _.each(this.socketEvents, function (method, key) {
                self.socket.removeAllListeners(key + ":" + self.channelName);
            });
            this.socket.emit('unsubscribe:'+this.channelName,{
                room: this.channelName
            });
            $(window).off("resize", this.onResize);
        },
        render: function () {
            this.$el.html(this.template());
        },
        getNumPerRow: function () {
            var len = _.size(this.videos);
            var biggest;

            // Ensure length is even for better division.
            if (len % 2 === 1) {
                len++;
            }

            biggest = Math.ceil(Math.sqrt(len));
            while (len % biggest !== 0) {
                biggest++;
            }
            return biggest;
        },

        subdivideVideos: function () {
            var videos = _.values(this.videos);
            var perRow = this.getNumPerRow();
            var numInRow = 0;
            console.log(videos, videos.length);
            for (var i = 0, len = videos.length; i < len; i++){
                var video = videos[i];
                this.setWH(video, i,len);
                numInRow = (numInRow + 1) % perRow;
            }
        },

        setWH: function (video, i,len) {
            var $container = $(".videos", this.$el),
                containerW = $container.width(),
                containerH = $container.height();

            var perRow = this.getNumPerRow();
            var perColumn = Math.ceil(len / perRow);
            var width = Math.floor((containerW) / perRow);
            var height = Math.floor((containerH) / perColumn);
            video.css({
                width: width,
                height: height,
                position: "absolute",
                left: (i % perRow) * width + "px",
                top: Math.floor(i / perRow) * height + "px"
            });
        },

        createVideoElement: function (clientID) {
            var client = this.channel.clients.findWhere({id: clientID}),
                clientNick = client.getNick(), // TODO: handle encrypted version
                $video = $(this.streamTemplate({
                    id: clientID,
                    nick: clientNick
                }));

            // keep track of the $element by clientID
            this.videos[clientID] = $video;

            // add the new stream element to the container
            $(".videos", this.$el).append($video);

            return $video;
        },

        removeVideo: function (id) {
            var video = this.videos[id];
            console.log("video", id, video);
            if (video) {
                video.remove();
                delete this.videos[id];
            }
        },

        initFullScreen: function() {
            var button = document.getElementById("fullscreen");
            button.addEventListener('click', function (event) {
                var elem = document.getElementById("videos");
                //show full screen
                elem.webkitRequestFullScreen();
            });
        }
    });
});