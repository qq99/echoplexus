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
		drawingView: new DrawingClient({
			namespace: "/draw"
		}),
		initialize: function () {
			var self = this,
				channelsFromLastVisit = window.localStorage.getObj("joined_channels");

			_.bindAll(this);

			this.sortedChannelNames = [];
			this.channels = {};
			this.codeChannels = {};
			this.drawingChannels = {};

			if (channelsFromLastVisit && channelsFromLastVisit.length) {
				_.each(channelsFromLastVisit, function (channelName) {
					self.joinChannel(channelName);
				});
			}

			// join the root channel by default:
			this.joinChannel("/");

			// join the URL slug channel by default:
			var defaultChannel = window.location.pathname;
			this.joinChannel(defaultChannel);

			if (window.localStorage.getObj("activeChannel")) {
				this.showChannel(window.localStorage.getObj("activeChannel"));
			} else {
				this.showChannel("/"); // show the default
			}

			this.attachEvents();
		},
		attachEvents: function () {
			var self = this;

			// show an input after clicking "+ Join Channel"
			this.$el.on("click", ".join", function () {
				var $input = $(this).siblings("input");
				if ($input.is(":visible")) {
					$input.fadeOut();
				} else {
					$input.fadeIn();
				}
			});

			// join a channel by typing in the name after clicking the "+ Join Channel" button and clicking enter
			this.$el.on("keydown", "input.channelName", function (ev) {
				if (ev.keyCode === 13) { // enter key
					var channelName = $(this).val();
					ev.preventDefault();
					self.joinAndShowChannel(channelName);
				}
			});

			// make the channel corresponding to the clicked channel button active:
			this.$el.on("click", ".channels .channelBtn", function (ev) {
				var channel = $(this).data("channel");
				self.showChannel(channel);
			});

			// kill the channel when clicking the channel button's close icon
			this.$el.on("click", ".close", function (ev) {
				ev.preventDefault();
				ev.stopPropagation();
				var $chatButton = $(this).parents(".channelBtn"),
					channel = $chatButton.data("channel");
				self.leaveChannel(channel);
			});

			this.on("nextChannel", this.showNextChannel);
			this.on("previousChannel", this.showPreviousChannel);
			this.on("leaveChannel", function () {
				self.leaveChannel(self.activeChannel);
			});
		},

		leaveChannel: function (channelName) {
			// don't leave an undefined channel or the last channel
			if ((typeof channelName === "undefined") ||
				(this.sortedChannelNames.length === 1)) {
				
				return;
			}



			var channelView = this.channels[channelName],
				codeView = this.codeChannels[channelName],
				drawView = this.drawingChannels[channelName],
				$channelButton = this.$el.find(".channelBtn[data-channel='"+ channelName +"']");

			// remove the views, then their $els
			channelView.kill();
			channelView.$el.remove();
			codeView.kill();
			codeView.$el.remove();
			drawView.kill();
			drawView.$el.remove();

			// update / delete references:
			this.sortedChannelNames = _.without(this.sortedChannelNames, channelName);
			console.log(this.sortedChannelNames);
			delete this.activeChannel;
			delete this.channels[channelName];
			delete this.codeChannels[channelName];
			delete this.drawingChannels[channelName];

			// click on the button closest to this channel's button and activate it before we delete this one:
			if ($channelButton.prev().length) {
				$channelButton.prev().click();
			} else {
				$channelButton.next().click();
			}

			this.sortedChannelNames = _.uniq(this.sortedChannelNames);

			// update stored channels for revisit/refresh
			window.localStorage.setObj("joined_channels", this.sortedChannelNames);

			// remove the button in the channel switcher too:
			$channelButton.remove();
		},

		showNextChannel: function () {
			if (!this.hasActiveChannel()) {
				return;
			}

			var activeChannelIndex = _.indexOf(this.sortedChannelNames, this.activeChannel),
				targetChannelIndex = activeChannelIndex + 1;

			// prevent array OOB
			targetChannelIndex = targetChannelIndex % this.sortedChannelNames.length;

			this.showChannel(this.sortedChannelNames[targetChannelIndex]);
		},

		showPreviousChannel: function () {
			if (!this.hasActiveChannel()) {
				return;
			}

			var activeChannelIndex = _.indexOf(this.sortedChannelNames, this.activeChannel),
				targetChannelIndex = activeChannelIndex - 1;

			// prevent array OOB
			if (targetChannelIndex < 0) {
				targetChannelIndex = this.sortedChannelNames.length - 1;
			}

			this.showChannel(this.sortedChannelNames[targetChannelIndex]);
		},

		hasActiveChannel: function () {
			return (typeof this.activeChannel !== "undefined");
		},

		showChannel: function (channelName) {
			var self = this;
			var channelsToDeactivate = _.without(_.keys(this.channels), channelName);

			// tell the views to deactivate
			_.each(channelsToDeactivate, function (channelName) {
				self.channels[channelName].trigger("hide");
				self.codeChannels[channelName].trigger("hide");
				self.drawingChannels[channelName].trigger("hide");
			});

			// style the buttons depending on which view is active
			$(".channels .channelBtn", this.$el).removeClass("active");
			$(".channels .channelBtn[data-channel='"+ channelName + "']", this.$el)
				.addClass("active")
				.removeClass("activity");

			// send events to the view we're showing:
			this.channels[channelName].trigger("show");
			this.codeChannels[channelName].trigger("show");
			this.drawingChannels[channelName].trigger("show");

			// keep track of which one is currently active
			this.activeChannel = channelName;

			// allow the user to know that his channel can be joined via URL slug by updating the URL
			if (history.replaceState) {
				// replaceState rather than pushing to keep Back/Forward intact && because we have no other option to perform here atm
				history.replaceState(null,"",channelName);
			}

			// keep track of which one we were viewing:
			window.localStorage.setObj("activeChannel", channelName);
		},

		channelActivity: function (data) {
			var fromChannel = data.channelName;
			
			// if we hear that there's activity from a channel, but we're not looking at it, add a style to the button to notify the user:
			if (fromChannel !== this.activeChannel) {
				$(".channels .channelBtn[data-channel='"+ fromChannel +"']").addClass("activity");
			}
		},

		joinChannel: function (channelName) {
			var channel = this.channels[channelName];
			// join the chat portion
			DEBUG && console.log("creating view for", channelName);
			if (typeof channel === "undefined") {
				this.channels[channelName] = new this.channelView({
					room: channelName
				});
				this.channels[channelName]
					.on('joinChannel', this.joinAndShowChannel, this)
					.on('activity', this.channelActivity)
					.$el.hide(); // don't show by default
			}

			// also join the code portion
			DEBUG && console.log("creating code view for", channelName);
			channel = this.codeChannels[channelName];
			if (typeof channel === "undefined") {
				this.codeChannels[channelName] = new this.codeView({
					room: channelName
				});
				this.codeChannels[channelName].$el.hide(); // don't show by default
			}

			// also join the drawing portion
			DEBUG && console.log("creating drawing view for", channelName);
			channel = this.drawingChannels[channelName];
			if (typeof channel === "undefined") {
				this.drawingChannels[channelName] = new this.drawingView({
					room: channelName
				});
				this.drawingChannels[channelName].$el.hide(); // don't show by default
			}

			this.sortedChannelNames.push(channelName);
			this.sortedChannelNames = _.sortBy(this.sortedChannelNames, function (key) {
				return key;
			});
			this.sortedChannelNames = _.uniq(this.sortedChannelNames);

			// update stored channels for revisit/refresh
			window.localStorage.setObj("joined_channels", this.sortedChannelNames);

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
			_.each(this.drawingChannels, function (channelView) {
				var channelName = channelView.channelName;
				if (!$(".drawingClient[data-channel='"+ channelName +"']").length) {
					$("#drawing").append(channelView.$el);
				}
			});
		},

		joinAndShowChannel: function(channelName) {
			if (typeof channelName === "undefined" || channelName === null) return; // prevent null channel names

			if (channelName.charAt(0) !== '/') { // keep channel names consistent with URL slug
				channelName = '/' + channelName;
			}
			this.joinChannel(channelName);
			this.showChannel(channelName);
		}
	});

	return ChannelSwitcherView;
}