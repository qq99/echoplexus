define(['jquery','backbone','underscore','client', 'loader',
		'text!templates/channelSelector.html'
	],function($,Backbone, _,Client,Modules,channelSelectorTemplate){
		var modules = _.map(Modules,function(module){return module.view;}),
			ClientModel = Client.ClientModel,
			ClientsCollection = Client.ClientsCollection;

	return Backbone.View.extend({
		className: "channelSwitcher",
		template: _.template(channelSelectorTemplate),

		initialize: function () {
			var self = this,
				joinChannels = window.localStorage.getObj("joined_channels") || [];;
			_.bindAll(this);

			this.sortedChannelNames = [];
			this.loading = 0; //Wether scripts are loading (async lock)

			this.channels = {};

			if (!joinChannels.length) {
				joinChannels = []
			}
			joinChannels.push('/',window.location.pathname);

			_.each(_.uniq(joinChannels),function(chan){
				self.joinChannel(chan);
			});
			if (window.localStorage.getObj("activeChannel")) {
				self.showChannel(window.localStorage.getObj("activeChannel"));
			} else {
				self.showChannel("/"); // show the default
			}
			this.attachEvents();
		},
		attachEvents: function () {
			var self = this;
			window.events.on('joinChannel',function(channel){
				self.joinAndShowChannel(channel);
			});
			window.events.on('leaveChannel', function(channel){
				self.leaveChannel(channel);
			});
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

			// kill the channel when clicking the channel button's close icon
			this.$el.on("click", ".channels .channelBtn .close", function (ev) {
				var $chatButton = $(this).parents(".channelBtn"),
					channel = $chatButton.data("channel");

				ev.stopPropagation(); // prevent the event from bubbling up to the .channelBtn bound below
				ev.preventDefault();
				self.leaveChannel(channel);
			});

			// make the channel corresponding to the clicked channel button active:
			this.$el.on("click", ".channels .channelBtn", function (ev) {
				var channel = $(this).data("channel");

				self.showChannel(channel);
			});

			this.on("nextChannel", this.showNextChannel);
			this.on("previousChannel", this.showPreviousChannel);
			this.on("leaveChannel", function () {
				self.leaveChannel(self.activeChannel);
			});

			window.events.on("chat:activity", function (data) {
				self.channelActivity(data);
			});
		},

		leaveChannel: function (channelName) {
			// don't leave an undefined channel or the last channel
			if ((typeof channelName === "undefined") ||
				(this.sortedChannelNames.length === 1)) {
				return;
			}



			var channelViews = this.channels[channelName].modules,
				$channelButton = this.$el.find(".channelBtn[data-channel='"+ channelName +"']");

			// remove the views, then their $els
			_.each(channelViews,function(module,key){
				module.view.kill();
				module.view.$el.remove();
			});

			// update / delete references:
			this.sortedChannelNames = _.without(this.sortedChannelNames, channelName);
			delete this.activeChannel;
			delete this.channels[channelName];

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
			var callback = function(){
				if(self.loading > 0){
					setTimeout(callback,50);
					return;
				}
				self.showChannel(channelName);
			};
			if(self.loading > 0){
				setTimeout(callback,50);
				return;
			}
			DEBUG && console.log('showing channel: ' + channelName);
			var channelsToDeactivate = _.without(_.keys(this.channels), channelName);
			// tell the views to deactivate
			_.each(channelsToDeactivate, function (channelName) {
				_.each(self.channels[channelName].modules,function(module){
					module.view.$el.hide();
					module.view.trigger("hide");
				});
			});

			// style the buttons depending on which view is active
			$(".channels .channelBtn", this.$el).removeClass("active");
			$(".channels .channelBtn[data-channel='"+ channelName + "']", this.$el)
				.addClass("active")
				.removeClass("activity");

			// send events to the view we're showing:
			_.each(this.channels[channelName].modules,function(module){
				module.view.$el.show();
				module.view.trigger("show");
			});

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
			var self = this;
			DEBUG && console.log("creating view for", channelName);
			if(_.isUndefined(this.channels[channelName])) {
				this.loading += 1;
				require(modules,function(){ // dynamically load each of the modules defined in client/config.js
					var channel = {
						clients: new ClientsCollection(),
						modules: [],
						isPrivate: false
					};
					// create an instance of each module:
					_.each(arguments,function(ClientModule,idx){
						if (!_.isFunction(ClientModule)) return;
						var modInstance = {
							view: new ClientModule({
								channel: channel,
								room: channelName,
								config: Modules[idx]
							}),
							config: Modules[idx]
						};
						modInstance.view.$el.hide();

						channel.modules.push(modInstance);
					});

					self.channels[channelName] = channel;
					self.loading -= 1;
					self.render();
				});
			}

			this.sortedChannelNames.push(channelName);
			this.sortedChannelNames = _.sortBy(this.sortedChannelNames, function (key) {
				return key;
			});
			this.sortedChannelNames = _.uniq(this.sortedChannelNames);

			// update stored channels for revisit/refresh
			window.localStorage.setObj("joined_channels", this.sortedChannelNames);
		},

		render: function () {
			var channelNames = _.sortBy(_.keys(this.channels), function (key) {
				return key;
			});

			this.$el.html(this.template({
				channels: channelNames
			}));

			// clear out old pane:
			_.each(this.channels, function (channel,channelName) {
				var channelViews = channel.modules;

				_.each(channelViews,function(module){
					if (!$('.' + module.view.className + "[data-channel='"+ channelName +"']").length) {
						$('#'+module.config.section).append(module.view.$el);
					}
				});
			});
		},

		joinAndShowChannel: function(channelName) {
			var self = this;
			if (typeof channelName === "undefined" || channelName === null) return; // prevent null channel names

			if (channelName.charAt(0) !== '/') { // keep channel names consistent with URL slug
				channelName = '/' + channelName;
			}
			this.joinChannel(channelName);
			this.showChannel(channelName);
		}
	});
});