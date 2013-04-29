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
					self.joinChannel($(this).val());
				}
			});

			this.$el.on("click", ".channels .channelBtn", function () {
				var channel = $(this).data("channel");
				$(this).siblings().removeClass("active");
				$(this).addClass("active");
				$(".chatChannel").hide()
				$(".chatChannel[data-channel='"+ channel +"']").show();
			});
		},
		joinChannel: function (channelName) {
			var channel = this.channels[channelName];
			console.log("creating view for", channelName);
			if (typeof channel === "undefined") {
				this.channels[channelName] = new this.channelView({
					room: channelName
				});
			}
			this.render();
		},
		render: function () {
			var channelNames = _.keys(this.channels);

			this.$el.html(this.template({
				channels: channelNames
			}));

			// clear out old pane:
			$("#chatting").html("");
			_.each(this.channels, function (channelView) {
				$("#chatting").append(channelView.$el);
			});
		}
	});

	return ChannelSwitcherView;
}