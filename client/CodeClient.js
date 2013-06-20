define(['jquery','underscore','backbone','codemirror','ui/SyncedEditor','text!templates/jsCodeRepl.html'],
    function($,_,Backbone,CodeMirror,SyncedEditor,jsCodeReplTemplate){
    // this is really the JSHTML code client:
    return Backbone.View.extend({
        className: "codeClient",

        htmlEditorTemplate: _.template(jsCodeReplTemplate),

        initialize: function (opts) {
            var self = this;

            _.bindAll(this);

            this.channelName = opts.room;

            this.listen();
            this.render();

            // debounce a function for auto-repling
            this.doREPL = _.debounce(this._repl, 500);

            this.editors = {
                "js": this.editorTemplates.SimpleJS($(".jsEditor", this.$el)[0]),
                "html": this.editorTemplates.SimpleHTML($(".htmlEditor", this.$el)[0])
            };

            var syncedEditor = new SyncedEditor();
            

            this.syncedJs = new syncedEditor({
                room: this.channelName,
                subchannel: "js",
                editor: this.editors["js"]
            });
            this.syncedHtml = new syncedEditor({
                room: this.channelName,
                subchannel: "html",
                editor: this.editors["html"]
            });
            this.repl = $(".jsREPL .output", this.$el)

            this.attachEvents();

            // currently triggered when user selects another channel:
            // perhaps should also be triggered when a user chooses a different tab
            this.on("show", this.show);
            this.on("hide", this.hide);

            //Is the REPL loaded?
            this.isIframeAvailable = false;
            //Wether to evaluate immediately on REPL load
            this.runNext = false;
        },

        hide: function () {
            DEBUG && console.log("code_client:hide");
            this.$el.hide();
            this.syncedJs.trigger("hide");
            this.syncedHtml.trigger("hide");
            // turn off live-reloading if we hide this view
            // don't want to execute potential DoS code that was inserted while we were away
            if (this.$livereload_checkbox &&
                this.$livereload_checkbox.is(":checked")) {
                this.$livereload_checkbox.attr("checked", false);
            }
        },

        show: function () {
            DEBUG && console.log("code_client:show");
            this.$el.show();
            this.syncedJs.trigger("show");
            this.syncedHtml.trigger("show");
        },

        kill: function () {
            var self = this;

            console.log("killing CodeClientView", self.channelName);

            this.syncedJs.kill();
            this.syncedHtml.kill();
        },

        livereload: function () {
            // only automatically evaluate the REPL if the user has opted in
            if (this.$livereload_checkbox && 
                this.$livereload_checkbox.is(":checked")) {
                //Reload the iframe (causes huge amounts of lag)
                //this.refreshIframe();
                this.doREPL();
            }
        },

        attachEvents: function () {
            var self = this;
            this.listenTo(this.syncedJs, "eval", this.livereload);
            this.listenTo(this.syncedHtml, "eval", this.livereload);
            $("body").on("codeSectionActive", function () {
                self.refresh();
            });
            $(window).on('message',function(e){
                if (e.originalEvent.data === "ready"){
                    self.isIframeAvailable = true;
                    if(self.runNext){
                        self._repl();
                        self.runNext = false;
                    }
                    return;
                }
                var data;
                try{
                    data = JSON.parse(decodeURI(e.originalEvent.data));
                    if (data.channel === self.channelName){
                        self.updateREPL(data.result);
                    }
                } catch(ex){
                    self.updateREPL(ex.toString());
                }
            });
            this.$el.on("click", ".evaluate", function (ev) {
                ev.preventDefault();
                ev.stopPropagation();
                self._repl(); // doesn't need to be the debounced version since the user is triggering it purposefully
            });
            this.$el.on("click", ".refresh",function(ev){
                ev.preventDefault();
                ev.stopPropagation();
                self.refreshIframe();
            })
        },

        refresh: function () {
            _.each(this.editors, function (editor) {
                editor.refresh();
            });
        },

        refreshIframe: function(){
            var iframe = $("iframe.jsIframe", this.$el)[0];
            iframe.src = iframe.src;
            this.isIframeAvailable = false;
        },

        updateREPL: function(result){
            if (_.isObject(result)) {
                result = JSON.stringify(result);
            }
            else if (typeof result === "undefined") {
                result = "undefined";
            }
            else {
                result = result.toString();
            }
            this.repl.text(result);
        },

        evaluate: function (code) {
            // var iframe = document.getElementById("repl-frame").contentWindow;
            if (typeof code === "undefined") {
                this.repl.text("");
                return;
            }
            
            var iframe = $("iframe.jsIframe", this.$el)[0];

            //Send the message
            iframe.contentWindow.postMessage(encodeURI(JSON.stringify({
                type: 'js',
                code: code,
                channel: this.channelName
            })),"*");
        },
        _repl: function () {
            if (!this.isIframeAvailable){
                this.runNext = true;
                return;
            }
            code = _.object(_.map(this.editors, function (editor,key) {
                return [key,editor.getValue()];
            }));
            // do HTML first so it's available to the user JS:
            //this.evaluateHTML(html);
            //this.evaluateJS(js);
            this.evaluate(code);
        },

        editorTemplates: {
            SimpleJS: function (domEl) {
                return CodeMirror.fromTextArea(domEl, {
                    lineNumbers: true,
                    mode: "text/javascript",
                    theme: "monokai",
                    matchBrackets: true,
                    highlightActiveLine: true,
                    continueComments: "Enter"
                });
            },
            SimpleHTML: function (domEl) {
                return CodeMirror.fromTextArea(domEl, {
                    lineNumbers: true,
                    mode: "text/html",
                    theme: "monokai"
                });
            }
        },

        listen: function () {

        },

        render: function () {
            this.$el.html(this.htmlEditorTemplate());
            this.$el.attr("data-channel", this.channelName);

            this.$livereload_checkbox = this.$el.find("input.livereload");
        }

    });
});