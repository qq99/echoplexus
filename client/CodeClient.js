function CodeClient (options) {
	// this is really the JSHTML code client:
	var CodeClientView = Backbone.View.extend({
		className: "codeClient",

		htmlEditorTemplate: _.template($("#jsCodeReplTemplate").html()),

		initialize: function (opts) {
			var self = this;

			_.bindAll(this);

			this.channelName = opts.room;

			this.listen();
			this.render();

			// debounce a function for repling
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

			this.attachEvents();
		},

		attachEvents: function () {
			var self = this;
			this.listenTo(this.syncedJs, "eval", this.doREPL);
			this.listenTo(this.syncedHtml, "eval", this.doREPL);
		},

		show: function () {
			_.each(editors, function (editor) {
				editor.refresh();
			});
		},

		evaluateJS: function (userJs) {
			// var iframe = document.getElementById("repl-frame").contentWindow;
			var iframe = $("iframe.jsIframe", this.$el)[0];

			var wrapped_script = "(function(){ "; // execute in a closure
				wrapped_script+= "return (function(window,$,_,alert,undefined) {"; // don't allow user to override things
				wrapped_script+= userJs;
				wrapped_script+= "})(window,$,_, function () { return arguments; });";
				wrapped_script+= "})();";

			if (userJs !== "") {
				var result;
				try {
					result = iframe.contentWindow.eval(wrapped_script);
					if (_.isObject(result)) {
						result = JSON.stringify(result);
					} 
					else if (result === undefined) {
						result = "undefined";
					}
					else {
						result = result.toString();
					}
				} catch (e) {
					result = e.toString();
				}
				$(".jsREPL .output", this.$el).text(result);
			} else {
				$(".jsREPL .output", this.$el).text("");
			}

		},

		evaluateHTML: function (userHtml) {
			// var iframe = document.getElementById("repl-frame").contentWindow;

			// write the HTML
			var doc = $("iframe.jsIframe", this.$el)[0].contentDocument;
				doc.open();
				doc.write(userHtml);
				doc.close();

		},

		_repl: function () {

			var html = this.editors["html"].getValue();
			var js = this.editors["js"].getValue();

			// do HTML first so it's available to the user JS:
			this.evaluateHTML(html);
			this.evaluateJS(js);
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
		},

	});

	return CodeClientView; // todo: return a different view for different top-level options
}