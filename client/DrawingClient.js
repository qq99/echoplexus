(function() {
  var requestAnimationFrame = window.requestAnimationFrame || window.mozRequestAnimationFrame ||
                              window.webkitRequestAnimationFrame || window.msRequestAnimationFrame;
  window.requestAnimationFrame = requestAnimationFrame;
})();
function DrawingClient (options) {

    var TOOLS = {
        BRUSH: 1,
        ERASER: 2
    }

    function DrawQueue () {
        var fifo = [],
        executing = false;
        //Dat pun
        var exequeute = function () {
            if (!executing) { // simple lock
                executing = true;
            } else { // don't try to process same queue twice
                return;
            }

            while (fifo.length > 0) {
                var task = fifo.shift();

                task();
            }
            executing = false;
        };

        return {
            add: function (dfrdFnc) {
                fifo.push(dfrdFnc);
                exequeute();
            },
            run: function (dfrdFnc) {
                exequeute();
            }
        }
    }

    function TimeCapsule() {
        var time = 0;
        this.getLapse = function() {
            if (time === 0) time = (new Date()).getTime();
            var newTime = (new Date()).getTime();
            var delay = newTime - time;
            time = newTime;
            return delay;
        };
        return this;
    }

    // this is really the JSHTML code client:
    var DrawingClientView = Backbone.View.extend({
        className: "drawingClient",

        template: _.template($("#drawingTemplate").html()),

        initialize: function (opts) {
            var self = this;

            _.bindAll(this);

            this.socket = io.connect("/draw");
            this.channelName = opts.room;

            this.drawQ = new DrawQueue();
            //Initialize a path variable to hold the paths buffer as we recieve it from other clients
            this.paths = {};

            this.listen();
            this.render();

            //this.brush = new Brush((new ColorModel()).toRGB(), 2.0);
            this.style = {
                tool: TOOLS.BRUSH,
                globalAlpha: 1,
                globalCompositeOperation: "source-over",
                strokeStyle: (new ColorModel()).toRGB(),
                lineWidth: 10,
                lineCap: "round",
                lineJoin: "round"
            };

            // debounce a function for repling
            this.attachEvents();

            this.on("show", function () {
                DEBUG && console.log("drawing_client:show");
                self.$el.show();
            });

            this.on("hide", function () {
                DEBUG && console.log("drawing_client:hide");
                self.$el.hide();
            });
            this.layerForeground = this.$el.find('canvas.foreground')[0];
            this.layerBackground = this.$el.find('canvas.background')[0];
            this.layerActive = this.$el.find('canvas.active')[0];

            //Foreground (where other users draw)
            this.fctx = this.layerForeground.getContext('2d');
            //Background (where everything gets drawn ultimately)
            this.bctx = this.layerBackground.getContext('2d');
            //Active layer
            this.ctx = this.layerActive.getContext('2d');

            /*this.ctx.lineWidth = 2;
            this.ctx.strokeStyle = 'black';*/
            this.timeCapsule = null;
        },

        kill: function () {
            var self = this;

            DEBUG && console.log("killing DrawingClientView", self.channelName);
        },

        getCoords: function (ev) {
            if (typeof ev.offsetX === "undefined") {
                var offset = $(ev.target).offset();
                return {
                    x: ev.clientX - offset.left,
                    y: ev.clientY - offset.top
                };
            } else {
                return {
                    x: ev.offsetX,
                    y: ev.offsetY
                };
            }
        },

        startPath: function (coords) {

            this.cursorDown = true;
            this.buffer = [];
            this.timer = new TimeCapsule();
            this.movePath(_.extend(coords,{
                beginPath: true
            }));
        },
        movePath: function (coords) {
            if (!this.cursorDown) { return; }
            
            var ctx = this.ctx;
            //Update the style
            if (coords.beginPath){
                _.extend(ctx,this.style);
                coords.style = _.clone(this.style);
            }
            // store points for curve interp
            //this.buffer.push(pt);
            //this.streamBezier();
            // Record ms since last update.
            coords.lapse = this.timer.getLapse();
            // Push coords to current path.
            this.buffer.push(coords);

            //Stream the point out
            this.socket.emit("draw:line:" + this.channelName, {
                coord: coords
            });
            // Push coords to global path.
            //this.path.push(coords);
            // Reset the composite operation.
            // Clear the path being actively drawn.
            // Setup for eraser mode.
            // 
            ctx.globalCompositeOperation = "source-over";
            ctx.clearRect(0, 0, this.layerActive.width, this.layerActive.height);

            if (this.style.tool === TOOLS.ERASER) {
                this.layerBackground.style.display = "none";
                ctx.save();
                ctx.globalAlpha = 1;
                ctx.drawImage(this.layerBackground, 0, 0);
                ctx.restore();
                ctx.globalCompositeOperation = "destination-out";
            }
            ctx.save();
            //ctx.scale(this.zoom, this.zoom);
            this.catmull({
                path: this.buffer,
                ctx: ctx
            });
            ctx.restore();
            if(coords.endPath){
                if (this.style.tool == TOOLS.ERASER) {
                    this.layerBackground.style.display = "block";
                    this.bctx.clearRect(0, 0, innerWidth, innerHeight);
                }
                //Draw the current line to the background canvas
                this.bctx.drawImage(this.layerActive, 0, 0);
                //Clear the active layer
                this.ctx.clearRect(0, 0, this.layerActive.width, this.layerActive.height);
            }
        },
        stopPath: function (coords) {
            //Record what we just drew to the foreground and clean up
            this.movePath(_.extend(coords,{
                endPath: true
            }));

            this.cursorDown = false;
            /*if (dstEraser) {
                layer1.style.display = "block";
                ctx1.clearRect(0, 0, innerWidth, innerHeight);
            }*/
        },

        trash: function () {
            this.bctx.clearRect(0, 0, this.layerBackground.width, this.layerBackground.height);
            this.fctx.clearRect(0, 0, this.layerForeground.width, this.layerForeground.height);
            this.ctx.clearRect(0, 0, this.layerActive.width, this.layerActive.height);
        },

        attachEvents: function () {
            var self = this;

            this.samplePoints = _.throttle(this.movePath, 40);

            this.$el.on("mousedown", ".canvas-area", function (ev) {
                self.startPath(self.getCoords(ev));
            });
            this.$el.on("mouseup", ".canvas-area", function (ev) {
                self.stopPath(self.getCoords(ev));
            });
            this.$el.on("mousemove", ".canvas-area", function (ev) {
                if (!self.cursorDown) { return; }
                self.samplePoints(self.getCoords(ev));
            });


            this.$el.on("click", ".tool.trash", function () {
                DEBUG && console.log("emitting trash event");
                self.trash();
                self.socket.emit("trash:" + self.channelName, {});
            });

            this.$el.on("click", ".tool.eraser", function(){
                //TODO: Eraser code here
                self.style.tool = TOOLS.ERASER;
            });

            this.$el.on("click", ".swatch", function (ev) {
                self.style.strokeStyle = $(this).data("color");
            });

            this.$el.on("click", ".tool.pen", function () {
                
                $(this).find(".tool-options .swatch").each(function (index, ele) {
                    var randomColor = (new ColorModel()).toRGB();
                    $(ele).css("background", randomColor)
                        .data("color", randomColor);
                });

                $(this).find(".tool-options").toggleClass("active");
            });

            $(window).on("keydown", function (ev) {
                if (self.$el.is(":visible")) {
                    if (ev.keyCode === 221) { // } key
                        self.style.lineWidth += 0.25;
                    } else if (ev.keyCode === 219) { // { key
                        self.style.lineWidth -= 0.25;
                    }
                }
            });
        },

        showPenOptions: function () {

        },

        postSubscribe: function () {

        },

        refresh: function () {

        },

        listen: function () {
            var self = this,
            socket = this.socket;

            this.socketEvents = {
                "draw:line": function (msg) {
                    /*var line = new BezierLine(msg.fromX, msg.fromY, self.ctx, msg.ctxState, msg.bezier);
                    self.drawQ.add(line);*/
                    //Draw to the foreground context
                    var ctx = self.fctx;
                    self.paths[msg.cid] = (self.paths[msg.cid] || []);
                    if (msg.coord.beginPath){
                        self.paths[msg.cid] = [];
                    }
                    self.paths[msg.cid].push(msg.coord);
                    ctx.save();
                    //Load the style
                    _.extend(ctx,self.paths[msg.cid][0].style);
                    if (self.paths[msg.cid][0].style.tool === TOOLS.ERASER) {
                        self.layerBackground.style.display = "none";
                        ctx.globalAlpha = 1;
                        ctx.drawImage(self.layerBackground, 0, 0);
                        ctx.globalCompositeOperation = "destination-out";
                    }
                    //ctx.scale(this.zoom, this.zoom);
                    self.catmull({
                        path: self.paths[msg.cid],
                        ctx: ctx
                    });
                    ctx.restore();
                    if (msg.coord.endPath){
                        if (self.paths[msg.cid][0].style.tool == TOOLS.ERASER) {
                            self.layerBackground.style.display = "block";
                            self.bctx.clearRect(0, 0, innerWidth, innerHeight);
                        }
                        //Draw the current line to the background canvas
                        self.bctx.drawImage(self.layerForeground, 0, 0);
                        //Clear the foreground
                        self.fctx.clearRect(0, 0, self.layerForeground.width, self.layerForeground.height);
                    }
                },
                "trash": function () {
                    self.trash();
                }
            };
            _.each(this.socketEvents, function (value, key) {
                // listen to a subset of event
                socket.on(key + ":" + self.channelName, value);
            });

            // initialize the channel
            socket.emit("subscribe", {
                room: self.channelName
            }, this.postSubscribe);
            //On successful reconnect, attempt to rejoin the room
            socket.on("reconnect",function(){
                //Resend the subscribe event
                socket.emit("subscribe", {
                    room: self.channelName
                }, this.postSubscribe);
            });
        },

        render: function () {
            this.$el.html(this.template());
            this.$el.attr("data-channel", this.channelName);
        },

        //Catmull-Rom spline
        catmull: function (config) {
            var path = _.clone(config.path);
            var tension = 1 - (config.tension || 0);
            var ctx = config.ctx;
            var length = path.length - 3;
            path.splice(0, 0, path[0]);
            path.push(path[path.length - 1]);
            if (length <= 0) return;
            for (var n = 0; n < length; n ++) {
                var p1 = path[n];
                var p2 = path[n + 1];
                var p3 = path[n + 2];
                var p4 = path[n + 3];
                if (n === 0) {
                    ctx.beginPath();
                    ctx.moveTo(p2.x, p2.y);
                }
                ctx.bezierCurveTo(
                    p2.x + (tension * p3.x - tension * p1.x) / 6,
                    p2.y + (tension * p3.y - tension * p1.y) / 6,
                    p3.x + (tension * p2.x - tension * p4.x) / 6,
                    p3.y + (tension * p2.y - tension * p4.y) / 6,
                    p3.x, p3.y
                );
            }
            ctx.stroke();
        }

    });

    return DrawingClientView; // todo: return a different view for different top-level options
}