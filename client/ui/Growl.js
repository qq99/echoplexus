define(['jquery','underscore','backbone',
		"text!templates/GrowlNotification.html"],
	function($, _, Backbone, growlTemplate){

	// Displays a little modal-like alert box with
	var GrowlNotification = Backbone.View.extend({

		template: _.template(growlTemplate),

		className: "growl",

		initialize: function (opts) {

			_.bindAll(this);

			// defaults
			this.position = "bottom right";
			this.padding = 10;

			// override defaults
			_.extend(this, opts);

			this.$el.html(this.template({
				title: opts.title,
				body: opts.body
			}));

			this.$el.addClass(this.position);

			this.place().show();

		},

		show: function () {
			var self = this;

			$("body").append(this.$el);
			_.defer(function () {
				self.$el.addClass("shown");
			});

			setTimeout(this.hide, 3000);

			return this;
		},

		hide: function () {
			var self = this;

			this.$el.removeClass("shown");
			window.events.trigger("growl:hide", {
				height: parseInt(self.$el.outerHeight(), 10)
			});

			setTimeout(function () {
				self.remove();
			});
		},

		place: function () {
			var cssString,
				curValue,
				$otherEl,
				$otherGrowls = $(".growl:visible." + this.position.replace(" ", ".")); // finds all with the same position settings as ours

			if (this.position.indexOf("bottom") !== -1) {
				cssString = "bottom";
			} else {
				cssString = "top";
			}


			var max = -Infinity,
				heightOfMax = 0;
			// find the offset of the highest visible growl
			// and place ourself above it
			for (var i = 0; i < $otherGrowls.length; i++) {
				var $otherEl = $($otherGrowls[i]);

				curValue = parseInt($otherEl.css(cssString), 10);
				if (curValue > max) {
					max = curValue;
					heightOfMax = $otherEl.outerHeight();
				}
			}

			max += heightOfMax;
			max += this.padding; // some padding

			this.$el.css(cssString, max);

			return this;
		},

	});

	return GrowlNotification;

});