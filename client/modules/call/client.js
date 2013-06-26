var PeerConnection = window.PeerConnection || window.webkitPeerConnection00 || window.webkitRTCPeerConnection || window.mozRTCPeerConnection || window.RTCPeerConnection;
define(['modules/call/rtc', 'text!modules/call/templates/callPanel.html'], function (RTC, callPanelTemplate) {
    return Backbone.View.extend({
        className: 'callClient',
        template: _.template(callPanelTemplate),
        initialize: function (opts) {
            var self = this;
            _.bindAll(this);
            this.channel = opts.channel;
            this.channelName = opts.room;
            this.socket = io.connect("/call");
            this.config = opts.config;
            this.rtc = new RTC();
            this.render();
            this.on("show", function () {
                DEBUG && console.log("call_client:show");
                self.$el.show();
                self.connect();
            });
            this.on("hide", function () {
                DEBUG && console.log("call_client:hide");
                self.$el.hide();
            });
            if (!PeerConnection)
                alert('Your browser is not supported or you have to turn on flags. In chrome you go to chrome://flags and turn on Enable PeerConnection remember to restart chrome');
            this.attachEvents();
            this.socket.emit("subscribe",{
                room: this.channelName
            },this.postSubscribe);
            //this.listen();
        },
        postSubscribe: function(){

        },
        attachEvents: function(){
            var self = this;
            window.events.on('sectionActive:'+this.config.section,function(){
                self.connect();
            });
        },
        connect: function(){
            var self = this;
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
                you.play();
                //videos.push(document.getElementById('you'));
                //rtc.attachStream(stream, 'you');
                //subdivideVideos();
            });
        },
        listen: function(){
            this.rtc.listen(this.socket, this.channelName);
            this.rtc.connect();
            this.rtc.on('add remote stream', function(stream, socketId) {
                console.log("ADDING REMOTE STREAM...");
                var clone = self.cloneVideo('you', socketId);
                clone.attr("class", "");
                self.rtc.attachStream(stream, clone.get(0));
                self.subdivideVideos();
            });
            this.rtc.on('disconnect stream', function(data) {
                console.log('remove ' + data);
                self.removeVideo(data);
            });
        },
        kill: function(){

        },
        render: function () {
            this.$el.html(this.template());
        },
        getNumPerRow: function () {
            var len = videos.length;
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
            var perRow = getNumPerRow();
            var numInRow = 0;
            for (var i = 0, len = videos.length; i < len; i++) {
                var video = videos[i];
                setWH(video, i);
                numInRow = (numInRow + 1) % perRow;
            }
        },

        setWH: function (video, i) {
            var perRow = getNumPerRow();
            var perColumn = Math.ceil(videos.length / perRow);
            var width = Math.floor((window.innerWidth) / perRow);
            var height = Math.floor((window.innerHeight - 190) / perColumn);
            video.width = width;
            video.height = height;
            video.style.position = "absolute";
            video.style.left = (i % perRow) * width + "px";
            video.style.top = Math.floor(i / perRow) * height + "px";
        },

        cloneVideo: function (domID, clientID) {
            var video = $(domID,this.$el).clone().attr('id','remote'+clientID);
            videos.push(video);
            video.appendTo($('#videos',this.$el));
            return video;
        },

        removeVideo: function (id) {
            var video = document.getElementById('remote' + socketId);
            if (video) {
                videos.splice(videos.indexOf(video), 1);
                video.parentNode.removeChild(video);
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