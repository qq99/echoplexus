function ChannelSwitcher (options) {
	var ChannelSwitcherView = Backbone.View.extend({
		className: "channelSwitcher",
		template: _.template($("#channelSelectorTemplate").html()),

		channelView: new ChatChannel({
			namespace: "/chat"
		}),
		initialize: function () {
			var self = this;

			_.bindAll(this);

			var defaultChat = new this.channelView({
				room: window.location.pathname
			});
			this.channels = {};
			this.channels[window.location.pathname] = defaultChat;

			this.render();

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
					ev.preventDefault();
					self.joinChannel($(this).val());
				}
			});

			this.$el.on("click", ".channels .channelBtn", function (ev) {
				var channel = $(this).data("channel");
				$(this).siblings().removeClass("active");
				$(this).addClass("active");
				$(".chatChannel").hide()
				$(".chatChannel[data-channel='"+ channel +"']").show();
				self.channels[channel].chatLog.scrollToLatest();
			});

			this.$el.on("click", ".close", function (ev) {
				ev.preventDefault();
				ev.stopPropagation();
				var $chatButton = $(this).parents(".channelBtn");
				var channel = $chatButton.data("channel");
				var channelView = self.channels[channel];
				channelView.kill();
				channelView.$el.remove();
				delete self.channels[channel];
				$chatButton.remove();
			});
		},
		joinChannel: function (channelName) {
			var channel = this.channels[channelName];
			console.log("creating view for", channelName);
			if (typeof channel === "undefined") {
				this.channels[channelName] = new this.channelView({
					room: channelName
				});
				this.channels[channelName].$el.hide(); // don't show by default
			}
			this.render();
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
		}
	});

	return ChannelSwitcherView;
}