if (typeof DEBUG === 'undefined') DEBUG = true; // will be removed

function codingModeActive () { // sloppy, forgive me
    return $("#coding").is(":visible");
}
function chatModeActive () {
    return $("#chatting").is(":visible");
}

$(document).ready(function () {
    
    // tooltip stuff:s
    $("body").on("mouseenter", ".tooltip-target", function(ev) {
        var title = $(this).data("tooltip-title");
        var body = $(this).data("tooltip-body");
        var tclass = $(this).data("tooltip-class");

        var $tooltip = $(tooltipTemplate);
        var $target = $(ev.target);
        if (!$target.hasClass("tooltip-target")) { // search up to find the true tooltip target
            $target = $target.parents(".tooltip-target");
        }
        var targetOffset = $target.offset();
        $tooltip.css({
            left: targetOffset.left + ($target.width()/2),
            top: targetOffset.top + ($target.height())
        }).addClass(tclass)
            .find(".title").text(title)
        .end()
            .find(".body").text(body);

        this.tooltip_timer = setTimeout(function () {
            $("body").append($tooltip);
            $tooltip.fadeIn();
        },350);
    }).on("mouseleave", ".tooltip-target", function (ev) {
        clearTimeout(this.tooltip_timer);
        $("body .tooltip").fadeOut(function () {
            $(this).remove();
        });
    });

    // consider these persistent options
    // we use a cookie for these since they're small and more compatible
    window.OPTIONS = {
        "autoload_media": true,
        "suppress_join": false,
        "highlight_mine": true,
        "suppress_client": false
    };


    function updateOption (value, option) {
        var $option = $("#" + option);
        //Check if the options are in the cookie, if so update the value
        if (typeof $.cookie(option) !== "undefined") value = !($.cookie(option) === "false");
        window.OPTIONS[option] = value;
        if (value) {
            $("body").addClass(option);
            $option.attr("checked", "checked");
        } else {
            $("body").removeClass(option);
            $option.removeAttr("checked");
        }
        // bind events to the click of the element of the same ID as the option's key
        $option.on("click", function () {
            $.cookie(option, $(this).prop("checked"));
            OPTIONS[option] = !OPTIONS[option];
            if (OPTIONS[option]) {
                $("body").addClass(option);
            } else {
                $("body").removeClass(option);
            }
            // chat.scroll();
        });
    }

    _.each(window.OPTIONS, updateOption); // update all options we know about

    $(".options-list .header button, .options-list .header .button").on("click", function () {
        var panel = $(this).parent().siblings(".options");
        if (panel.is(":visible")) {
            panel.slideUp();
        } else {
            panel.slideDown();
        }
    });


    // ghetto templates:
    var tooltipTemplate = $("#tooltip").html();

    window.notifications = new UserNotifications();
    window.uniqueImages = {};

    $(window).on("blur", function () {
        $("body").addClass("blurred");
    }).on("focus", function () {
        $("body").removeClass("blurred");
    });

    io.connect(window.location.origin,{
        'connect timeout': 1000,
        'reconnect': true,
        'reconnection delay': 2000,
        'max reconnection attempts': 1000
    });

    var channelSwitcherView = new ChannelSwitcher();
    var channelSwitcher = new channelSwitcherView();
    $("header").append(channelSwitcher.$el);

    // socket.on('connect', function () {

    notifications.enable();

    $("#chatting").on("hover", ".chatMessage", function (ev) {
        var $time = $(".time", this);
        $(this).attr("title", "sent " + moment($time.data("timestamp")).fromNow());
    });
    $("#chatting").on("hover", ".user", function (ev) {
        var $idle = $(this).find(".idle");
        if ($idle.length) {
            $(this).attr("title", "Idle since " + moment($idle.data("timestamp")).fromNow());
        }
    });

    $("span.options").on("click", function (ev) {
        $(this).siblings("div.options").toggle();
    });

    $(window).on("click", function () {
        notifications.request();
    });

    // messy, hacky, but make it safer for now
    function turnOffLiveReload () {
        $(".livereload").attr("checked", false);
    }

    $("#codeButton").on("click", function (ev) {
        ev.preventDefault();
        if ($("#coding:visible").length === 0) {
            $(this).addClass("active").siblings().removeClass("active");
            $("#panes > section").not('#coding').fadeOut();
            $("#coding").fadeIn(function () {
                $("body").trigger("codeSectionActive"); // sloppy, forgive me
            });
        }
    });

    $("#chatButton").on("click", function (ev) {
        ev.preventDefault();
        $(this).removeClass("activity");
        if ($("#chatting:visible").length === 0) {
            $(this).addClass("active").siblings().removeClass("active");
            $("#panes > section").not('#chatting').fadeOut();
            $("#chatting").fadeIn();
            $(".ghost-cursor").remove();
            turnOffLiveReload();
        }
    });

    $("#drawButton").on("click", function (ev) {
        ev.preventDefault();
        $(this).removeClass("activity");
        if ($("#drawing:visible").length === 0) {
            $(this).addClass("active").siblings().removeClass("active");
            $("#panes > section").not('#drawing').fadeOut();
            $("#drawing").fadeIn();
            $(".ghost-cursor").remove();
            turnOffLiveReload();
        }
    });

});