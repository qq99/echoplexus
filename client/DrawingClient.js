function DrawingClient (options) {

    function DrawQueue () {
        var fifo = [],
        executing = false;

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

    function BezierLine (fromX, fromY, ctx, opts, bezier) {
        var x = fromX,
            y = fromY;
        return function () {
            _.extend(ctx, opts); // set lineWidth, strokeStyle, etc
            ctx.beginPath();
            ctx.moveTo(x,y);
            ctx.bezierCurveTo.apply(ctx, bezier);
            ctx.stroke();
        }
    }

    function Brush (color, stroke) {
        return {
            strokeStyle: color,
            lineWidth: stroke
        };
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

            this.listen();
            this.render();

            this.brush = new Brush((new ColorModel()).toRGB(), 2.0);

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

            this.fctx = this.$el.find('canvas.feedback')[0].getContext('2d');
            this.ctx = this.$el.find('canvas.real')[0].getContext('2d');
            this.ctx.lineWidth = 2;
            this.ctx.strokeStyle = 'black';
            var ctx = this.ctx;
        },

        kill: function () {
            var self = this;

            DEBUG && console.log("killing DrawingClientView", self.channelName);
        },

        calculateControlPoints: function (p0, p1, p2, p3) {
            var smooth_value = 1.0;
            // http://www.antigrain.com/research/bezier_interpolation/
            var x0 = p0.x, 
                y0 = p0.y,
                x1 = p1.x,
                y1 = p1.y,
                x2 = p2.x,
                y2 = p2.y,
                x3 = p3.x,
                y3 = p3.y;

            var xc1 = (x0 + x1) / 2.0;
            var yc1 = (y0 + y1) / 2.0;
            var xc2 = (x1 + x2) / 2.0;
            var yc2 = (y1 + y2) / 2.0;
            var xc3 = (x2 + x3) / 2.0;
            var yc3 = (y2 + y3) / 2.0;

            var len1 = Math.sqrt((x1-x0) * (x1-x0) + (y1-y0) * (y1-y0));
            var len2 = Math.sqrt((x2-x1) * (x2-x1) + (y2-y1) * (y2-y1));
            var len3 = Math.sqrt((x3-x2) * (x3-x2) + (y3-y2) * (y3-y2));

            var k1 = len1 / (len1 + len2);
            var k2 = len2 / (len2 + len3);

            var xm1 = xc1 + (xc2 - xc1) * k1;
            var ym1 = yc1 + (yc2 - yc1) * k1;

            var xm2 = xc2 + (xc3 - xc2) * k2;
            var ym2 = yc2 + (yc3 - yc2) * k2;

            // Resulting control points. Here smooth_value is mentioned
            // above coefficient K whose value should be in range [0...1].
            ctrl1_x = xm1 + (xc2 - xm1) * smooth_value + x1 - xm1;
            ctrl1_y = ym1 + (yc2 - ym1) * smooth_value + y1 - ym1;

            ctrl2_x = xm2 + (xc2 - xm2) * smooth_value + x2 - xm2;
            ctrl2_y = ym2 + (yc2 - ym2) * smooth_value + y2 - ym2;
            return [ctrl1_x, ctrl1_y, ctrl2_x, ctrl2_y];
        },

        streamBezier: function () {
            var buffer = this.buffer,
                ctx = this.ctx,
                i = 1;

            if (buffer.length < 4) { return; }

            var p0 = buffer[i-1],
                p1 = buffer[i],
                p2 = buffer[i+1],
                p3 = buffer[i+2];

            var to = p2;

            var bezier = this.calculateControlPoints(p0,p1,p2,p3);
            bezier.push(to.x, to.y);

            var line = new BezierLine(buffer[i].x, buffer[i].y, ctx, this.brush, bezier);
            this.drawQ.add(line);

            this.socket.emit("draw:line:" + this.channelName, {
                fromX: buffer[i].x,
                fromY: buffer[i].y,
                ctxState: this.brush,
                bezier: bezier
            });

            this.buffer.shift();
        },

        getCoords: function (ev) {
            if (typeof ev.offsetX === "undefined") {
                var offset = $(ev.target).offset();
                return {
                    x: ev.clientX - offset.left,
                    y: ev.clientY - offset.top
                }
            } else {
                return {
                    x: ev.offsetX,
                    y: ev.offsetY
                };
            }
        },

        startPath: function (pt) {
            // user feedback:
            // this.fctx.beginPath();
            // this.fctx.moveTo(pt.x, pt.y);

            // store points for curve interp
            this.buffer = [];
            this.buffer.push(pt);
        },
        movePath: function (pt) {
            if (!this.cursorDown) { return; }
            // this.fctx.lineTo(pt.x, pt.y);
            // this.fctx.stroke();

            // store points for curve interp
            this.buffer.push(pt);
            this.streamBezier();
        },
        stopPath: function (pt) {
            // this.fctx.clearRect(0,0,1000,1000);

            this.buffer.push(pt);
            this.buffer.push(pt);

        },

        trash: function () {
            this.ctx.clearRect(0,0,1000,1000);
        },

        attachEvents: function () {
            var self = this;

            this.samplePoints = _.throttle(this.movePath, 40);

            this.$el.on("mousedown", ".canvas-area", function (ev) {
                self.cursorDown = true;
                self.startPath(self.getCoords(ev));
            });
            this.$el.on("mouseup", ".canvas-area", function (ev) {
                self.cursorDown = false;
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

            this.$el.on("click", ".swatch", function (ev) {
                self.brush.strokeStyle = $(this).data("color");
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
                        self.brush.lineWidth += 0.25;
                    } else if (ev.keyCode === 219) { // { key
                        self.brush.lineWidth -= 0.25;
                    }
                }
            });
        },

        showPenOptions: function () {

        },

        refresh: function () {

        },

        listen: function () {
            var self = this,
            socket = this.socket;

            this.socketEvents = {
                "draw:line": function (msg) {
                    var line = new BezierLine(msg.fromX, msg.fromY, self.ctx, msg.ctxState, msg.bezier);
                    self.drawQ.add(line);
                },
                "trash": function () {
                    self.trash();
                }
            }

            _.each(this.socketEvents, function (value, key) {
                // listen to a subset of event
                socket.on(key + ":" + self.channelName, value);
            });

            // initialize the channel
            socket.emit("subscribe", {
                room: self.channelName
            });
            //On successful reconnect, attempt to rejoin the room
            socket.on("reconnect",function(){
                //Resend the subscribe event
                socket.emit("subscribe", {
                    room: self.channelName
                });
            });
        },

        render: function () {
            this.$el.html(this.template());
            this.$el.attr("data-channel", this.channelName);
        },

    });

    return DrawingClientView; // todo: return a different view for different top-level options
}