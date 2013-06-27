
// object: a persistent log if local storage is available ELSE noops
define(['underscore'],function(_){
	return function(opts) {
		"use strict";
		var latestID = -Infinity,
			LOG_VERSION = "0.0.2", // update if the server-side changes
			log = [], // should always be sorted by timestamp
			options = {
				namespace: "default",
				logMax: 512
			};

		// extend defaults with any custom paramters
		_.extend(options, opts);


		if (window.Storage) {
			var version = window.localStorage.getItem("logVersion:" + options.namespace);
			if (typeof version === "undefined" || version === null || version !== LOG_VERSION) {
				window.localStorage.setObj("log:" + options.namespace, null);
				window.localStorage.setItem("logVersion:" + options.namespace, LOG_VERSION);
			}
			var prevLog = window.localStorage.getObj("log:" + options.namespace);
			
			if (log.length > options.logMax) { // kill the previous log, getting too big; TODO: make this smarter
				window.localStorage.setObj("log:" + options.namespace, null);
			} else if (prevLog) {
				log = prevLog;
			}

			return {
				add: function (obj) {
					if (obj.log && obj.log === false) return; // don't store things we're explicitly ordered not to
					if (obj.timestamp === false) return; // don't store things without a timestamp

					if (obj.mID && obj.mID > latestID) { // keep track of highest so far
						latestID = obj.mID;
					}

					// insert into the log
					log.push(obj);

					// sort the log for consistency:
					log = _.sortBy(log, "timestamp");

					// cull the older log entries
					if (log.length > options.logMax) {
						log.unshift();
					}

					// presist to localStorage:
					window.localStorage.setObj("log:" + options.namespace, log);
				},
				destroy: function () {
					log = [];
					window.localStorage.setObj("log:" + options.namespace, null);
				},
				empty: function () {
					return (log.length === 0);
				},
				all: function () {
					return log;
				},
				latestIs: function (id) {
					id = parseInt(id, 10);
					if (id > latestID) {
						latestID = id;
					}
				},
				knownIDs: function () {
					// compile a list of the message IDs we know about
					var known = _.without(_.map(log, function (obj) {
						return obj.mID;
					}), undefined);

					return known;
				},
				getMessage: function (byID) {
					var start = log.length - 1;

					for (var i = start; i > 0; i--) {
						if (log[i].mID === byID) {
							return log[i];
						}
					}
					return null;
				},
				replaceMessage: function (msg) {
					var start = log.length - 1;

					for (var i = start; i > 0; i--) {
						if (log[i].mID === msg.mID) {
							log[i] = msg;

							// presist to localStorage:
							window.localStorage.setObj("log:" + options.namespace, log);
							return;
						}
					}
				},
				getListOfMissedMessages: function () {
					var known = this.knownIDs(),
						clientLatest = known[known.length-1],
						missed = [],
						sensibleMax = 50, // don't pull everything that we might have missed, just the most relevant range
						from = latestID,
						to = Math.max(latestID - sensibleMax, clientLatest + 1);

					console.log(from, latestID - sensibleMax, clientLatest + 1);
					// if the server is ahead of us
					if (latestID > clientLatest) {
						for (var i = from; i >= to; i--) {
							missed.push(i);
						}
					} else {
						return null;
					}

					return missed;
				},
				getMissingIDs: function (N) { // fills in any holes in our chat history
					// compile a list of the message IDs we know about
					var known = this.knownIDs();
					// if we don't know about the server-sent latest ID, add it to the list:
					if (known[known.length-1] !== latestID) {
						known.push(latestID);
					}
					known.unshift(-1); // a default element

					// DEBUG && console.log("we know:", known);

					// compile a list of message IDs we know nothing about:
					var holes = [];
					for (var i = known.length - 1; i > 0; i--) {
						var diff = known[i] - known[i-1];
						for (var j = 1; j < diff; j++) {
							holes.push(known[i] - j);
							if (N && (holes.length === N)) { // only get N holes if we were requested to limit ourselves
								DEBUG && console.log("we don't know:", holes);
								return holes;
							}
						}
					}
					// DEBUG && console.log("we don't know:", holes);
					return holes;
				}
			};
		} else { /// return a fake for those without localStorage
			return {
				add: function () {},
				empty: function () { return true; },
				all: function () {
					return log;
				}
			};
		}
	};
});