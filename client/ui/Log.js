// object: a persistent log if local storage is available ELSE noops
function Log() {
	"use strict";
	var latestID = -Infinity,
		LOG_VERSION = "0.0.1", // update if the server-side changes
		log = [], // should always be sorted by timestamp
		logMax = 512;


	// utility: extend the local storage protoype if it exists
	if (window.Storage) {
		Storage.prototype.setObj = function(key, obj) {
			return this.setItem(key, JSON.stringify(obj));
		};
		Storage.prototype.getObj = function(key) {
			return JSON.parse(this.getItem(key));
		};
	}

	if (window.Storage) {
		var version = window.localStorage.getItem("logVersion");
		if (typeof version === "undefined" || version === null || version !== LOG_VERSION) {
			window.localStorage.setObj("log", null);
			window.localStorage.setItem("logVersion", LOG_VERSION);
		}
		var prevLog = window.localStorage.getObj("log");
		
		if (log.length > logMax) { // kill the previous log, getting too big; TODO: make this smarter
			window.localStorage.setObj("log", null);
		} else if (prevLog) {
			log = prevLog;
		}

		return {
			add: function (obj) {
				if (obj.log === false) return; // don't store things we're explicitly ordered not to
				if (obj.timestamp === false) return; // don't store things without a timestamp

				if (obj.ID && obj.ID > latestID) { // keep track of highest so far
					latestID = obj.ID;
				}

				// insert into the log
				log.push(obj);

				// sort the log for consistency:
				log = _.sortBy(log, "timestamp");

				// cull the older log entries
				if (log.length > logMax) {
					log.unshift();
				}

				// presist to localStorage:
				window.localStorage.setObj("log", log);
			},
			empty: function () {
				return (log.length === 0);
			},
			all: function () {
				return log;
			},
			latestID: function () {
				return smallestSeenMessageID;
			},
			latestIs: function (id) {
				id = parseInt(id, 10);
				if (id > latestID) {
					latestID = id;
				}
			},
			getMissingIDs: function (N) {
				// compile a list of the message IDs we know about
				var known = _.without(_.map(log, function (obj) {
					return obj.ID;
				}), undefined);
				// if we don't know about the server-sent latest ID, add it to the list:
				if (known[known.length-1] !== latestID) {
					known.push(latestID);
				}
				known.unshift(-1); // a default element

				// console.log("we know:", known);

				// compile a list of message IDs we know nothing about:
				var holes = [];
				for (var i = known.length - 1; i > 0; i--) {
					var diff = known[i] - known[i-1];
					for (var j = 1; j < diff; j++) {
						holes.push(known[i] - j);
						if (N && (holes.length === N)) { // only get N holes if we were requested to limit ourselves
							console.log("we don't know:", holes);
							return holes;
						}
					}
				}
				// console.log("we don't know:", holes);
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
}