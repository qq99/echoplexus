if (typeof DEBUG === 'undefined') DEBUG = true; // will be removed

function ChannelSwitcher (options) {
	var ChannelSwitcherView = Backbone.View.extend({
		className: "channelSwitcher",
		template: _.template($("#channelSelectorTemplate").html()),

		channelView: new ChatChannel({
			namespace: "/chat"
		}),
		codeView: new CodeClient({
			namespace: "/code",
			type: "htmljs"
		}),
		initialize: function () {
			var self = this;

			_.bindAll(this);

			this.channels = {};
			this.codeChannels = {};
			
			var defaultChannel = window.location.pathname;

			this.joinChannel(defaultChannel);
			this.showChannel(defaultChannel);

			this.attachEvents();
		},
		attachEvents: function () {
			var self = this;

			this.$el.on("click", ".join", function () {
				var $input = $(this).siblings("input");
				if ($input.is(":visible")) {
					$input.fadeOut();
				} else {
					$input.fadeIn();
				}
			});

			this.$el.on("keydown", "input.channelName", function (ev) {
				if (ev.keyCode === 13) { // enter key
					var channelName = $(this).val();
					ev.preventDefault();
					self.joinChannel(channelName);
					self.showChannel(channelName);
				}
			});

			this.$el.on("click", ".channels .channelBtn", function (ev) {
				var channel = $(this).data("channel");
				self.showChannel(channel);
			});

			this.$el.on("click", ".close", function (ev) {
				ev.preventDefault();
				ev.stopPropagation();
				var $chatButton = $(this).parents(".channelBtn");
				var $prevChatButton = $chatButton.prev();
				$prevChatButton.click(); // toggle the button before it

				var channel = $chatButton.data("channel");
				var channelView = self.channels[channel];
				var codeView = self.codeChannels[channel];
				channelView.kill();
				channelView.$el.remove();
				codeView.kill();
				codeView.$el.remove();
				delete self.channels[channel];
				delete self.codeChannels[channel];
				$chatButton.remove();
			});
		},

		showChannel: function (channelName) {
			var self = this;
			var channelsToDeactivate = _.without(_.keys(this.channels), channelName);

			// tell the views to deactivate
			_.each(channelsToDeactivate, function (channelName) {
				self.channels[channelName].trigger("hide");
				self.codeChannels[channelName].trigger("hide");
			});

			// style the buttons depending on which view is active
			$(".channels .channelBtn", this.$el).removeClass("active");
			$(".channels .channelBtn[data-channel='"+ channelName + "']", this.$el).addClass("active");

			// send events to the view we're showing:
			this.channels[channelName].trigger("show");
			this.codeChannels[channelName].trigger("show");
		},

		joinChannel: function (channelName) {
			var channel = this.channels[channelName];
			// join the chat portion
			DEBUG && console.log("creating view for", channelName);
			if (typeof channel === "undefined") {
				this.channels[channelName] = new this.channelView({
					room: channelName
				});
				this.channels[channelName].$el.hide(); // don't show by default
			}

			// also join the code portion
			DEBUG && console.log("creating code view for", channelName);
			if (typeof channel === "undefined") {
				this.codeChannels[channelName] = new this.codeView({
					room: channelName
				});
				this.codeChannels[channelName].$el.hide(); // don't show by default
			}

			this.render(); // re-render the channel switcher
		},

		render: function () {
			var channelNames = _.sortBy(_.keys(this.channels), function (key) {
				return key;
			});

			this.$el.html(this.template({
				channels: channelNames
			}));

			// clear out old pane:
			_.each(this.channels, function (channelView) {
				var channelName = channelView.channelName;
				if (!$(".chatChannel[data-channel='"+ channelName +"']").length) {
					$("#chatting").append(channelView.$el);
				}
			});
			_.each(this.codeChannels, function (channelView) {
				var channelName = channelView.channelName;
				if (!$(".codeClient[data-channel='"+ channelName +"']").length) {
					$("#coding").append(channelView.$el);
				}
			});
		}
	});

	return ChannelSwitcherView;
}