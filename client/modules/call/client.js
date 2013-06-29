define(['PeerConnection', 'modules/call/rtc', 'text!modules/call/templates/callPanel.html'], function (PeerConnection, RTC, callPanelTemplate) {
    return Backbone.View.extend({
        className: 'callClient',
        template: _.template(callPanelTemplate),

        events: {
            "click .join": "joinCall",
            "click .hang-up": "leaveCall"
        },

        initialize: function (opts) {
            var self = this;
            _.bindAll(this);
            this.channel = opts.channel;
            this.channelName = opts.room;
            this.socket = io.connect("/call");
            this.config = opts.config;
            this.rtc = new RTC();
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

            if (!PeerConnection) {
                $(".webrtc-error, no-webrtc", this.$el).show();
            }

            this.socket.emit('subscribe',{
                room: this.channelName
            });
        },

        showError: function (err, errMsg) {
            $(".no-call, .in-call", this.$el).hide();
            $(".webrtc-error, .reason.generic", this.$el).show();

            $(".reason.generic", this.$el).html("");
            $(".reason.generic", this.$el).append("<p>WebRTC failed!</p>");
            $(".reason.generic", this.$el).append("<p>" + errMsg + "</p>");
        },

        joinCall: function () {
            $(".no-call", this.$el).hide();
            this.connect();
        },

        leaveCall: function () {
            $(".in-call", this.$el).hide();
            this.disconnect();
            this.showCallInProgress();
        },

        connect: function(){
            if(!this.$el.is(':visible')) return;
            this.rtc.createStream({
                "video": {
                    "mandatory": {},
                    "optional": []
                },
                "audio": true
            }, function (stream) {
                var you = $('#you',this.$el).get(0);
                you.src = URL.createObjectURL(stream);
                you.muted = true;
                you.play();
                //videos.push(document.getElementById('you'));
                //rtc.attachStream(stream, 'you');
                //subdivideVideos();
            }, self.showError);
            this.rtc.connect();
            $(".no-call", this.$el).hide();
            $(".in-call", this.$el).show();
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
            this.rtc.listen(this.socket, this.channelName);
            this.rtc.on('add remote stream', function(stream, socketId) {
                console.log("ADDING REMOTE STREAM...");
                var clone = self.cloneVideo('#you', socketId);
                clone.attr("class", "");
                clone.get(0).muted = false;
                self.rtc.attachStream(stream, clone.get(0));
                self.subdivideVideos();
            });
            this.rtc.on('disconnect stream', function(data) {
                console.log('remove ' + data);
                self.removeVideo(data);
            });

            this.socketEvents = {
                "status": function(data){
                    if (data.active) {
                        self.showCallInProgress();
                    } else {
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
            this.rtc.disconnect();
            this.socket.emit('unsubscribe:'+this.channelName,{
                room: this.channelName
            });
        },
        kill: function(){
            var self = this;
            this.disconnect();
            _.each(this.socketEvents, function (method, key) {
                self.socket.removeAllListeners(key + ":" + self.channelName);
            });
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
            for (var i = 0, len = videos.length; i < len; i++){
                var video = videos[i];
                this.setWH(video, i,len);
                numInRow = (numInRow + 1) % perRow;
            }
        },

        setWH: function (video, i,len) {
            var perRow = this.getNumPerRow();
            var perColumn = Math.ceil(len / perRow);
            var width = Math.floor((window.innerWidth) / perRow);
            var height = Math.floor((window.innerHeight - 190) / perColumn);
            video.css({
                width: width,
                height: height,
                position: "absolute",
                left: (i % perRow) * width + "px",
                top: Math.floor(i / perRow) * height + "px"
            });
        },

        cloneVideo: function (domID, clientID) {
            var video = $(domID,this.$el).clone().attr('id','remote'+clientID);
            this.videos[clientID] = video;
            video.appendTo($('#videos',this.$el));
            return video;
        },

        removeVideo: function (id) {
            var video = this.videos[id];
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