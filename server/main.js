var config = require('./config.js').Configuration;
var Channels;
var express = require('express'),
	_ = require('underscore'),
	Backbone = require('backbone'),
	crypto = require('crypto'),
	fs = require('fs'),
	uuid = require('node-uuid'),
	redis = require('redis'),
	sio = require('socket.io'),
	app = express(),
	redisC = redis.createClient(),
	spawn = require('child_process').spawn,
	async = require('async'),
	path = require('path'),
	EventBus = new Backbone.Model(),
	chatServer = require('./ChatServer.js').ChatServer,
	codeServer = require('./CodeServer.js').CodeServer,
	drawServer = require('./DrawingServer.js').DrawingServer,
	callServer = require('./CallServer.js').CallServer,
	userServer = require('./UserServer.js').UserServer,
	ROOT_FOLDER = path.dirname(__dirname),
	PUBLIC_FOLDER = ROOT_FOLDER + '/public',
	SANDBOXED_FOLDER = PUBLIC_FOLDER + '/sandbox',
	CLIENT_FOLDER = ROOT_FOLDER + '/client',
	protocol, server;

// if we're using node's ssl, we must supply it the certs and create the server as https
if (config.ssl.USE_NODE_SSL) {
	protocol = require("https");
	var privateKey  = fs.readFileSync(config.ssl.PRIVATE_KEY).toString();
	var certificate = fs.readFileSync(config.ssl.CERTIFICATE).toString();
	var credentials = { key: privateKey, cert: certificate };
	server = protocol.createServer(credentials, app);
} else { // proxying via nginx allows us to use a simple http server (and connections will be upgraded)
	protocol = require("http");
	server = protocol.createServer(app);
}

var index = "public/index.dev.html";
if(fs.existsSync(PUBLIC_FOLDER+'/index.build.html'))
	index = "public/index.build.html";
console.log('Using index: ' + index);
// Custom objects:
// shared with the client:
var Client = require('../client/client.js').ClientModel,
	Clients = require('../client/client.js').ClientsCollection,
	REGEXES = require('../client/regex.js').REGEXES;


function urlRoot(){
	if (config.host.USE_PORT_IN_URL) {
		return config.host.SCHEME + "://" + config.host.FQDN + ":" + config.host.PORT + "/";
	} else {
		return config.host.SCHEME + "://" + config.host.FQDN + "/";
	}
}

// Web server init:
app.use('/client',express.static(CLIENT_FOLDER));


// xferc means 'transfer config'
var xferc = config.server_hosted_file_transfer;

if (xferc &&
	xferc.enabled &&
	xferc.size_limit) {

	app.use(express.limit(xferc.size_limit));
}

app.use(express.static(PUBLIC_FOLDER));

var bodyParser = express.bodyParser({
	uploadDir: SANDBOXED_FOLDER
});


// MW: MiddleWare
function authMW (req, res, next) {
	console.log(req.get("channel"), req.get("from_user"), req.get("antiforgery_token"), req.get("using_permission"));

	if (!xferc ||
		!xferc.enabled) {

		res.send(500, "Not enabled.");
		return;
	}

	EventBus.trigger("has_permission", {
		permission: req.get("Using-Permission"),
		channel: req.get("Channel"),
		from_user: req.get("From-User"),
		antiforgery_token: req.get("Antiforgery-Token")
	}, function (err, message) {
		if (err) {
			res.send(err, message);
			return;
		}
		next();
	});
}
// always server up the index
// 
// receive files
app.post('/*', authMW, bodyParser, function(req, res, next){

	var file = req.files.user_upload,
		uploadPath = file.path,
		newFilename = uuid.v4() + "." + file.name.replace(/ /g, "_"),
		finalPath = SANDBOXED_FOLDER + "/" + newFilename,
		serverPath = urlRoot() + "sandbox/" + newFilename;

	console.log(newFilename);

	// delete the file immediately if the message was malformed
	if (typeof req.get("From-User") === "undefined" ||
		typeof req.get("Channel") === "undefined") {

		fs.unlink(uploadPath, function (error) {
			if (error) {
				console.log(error.message);
			}
		});
		return;
	}

	// rename it with a uuid + the user's filename
	fs.rename(uploadPath, finalPath, function(error) {
		if(error) {
			res.send({
				error: 'Ah crap! Something bad happened'
			});
			return;
		}
		res.send({
			path: serverPath
		});
		EventBus.trigger("file_uploaded:" + req.get("Channel"), {
			from_user: req.get("From-User"),
			path: serverPath
		});
	});
});

app.get("/api/*", function (req, res) {
	if (req.route.params[0].indexOf("channels") !== -1) {
		res.set('Content-Type', 'application/json');

		var publicChannelInformation = [],
			publicChannels = Channels.where({private: false});

		for (var i = 0; i < publicChannels.length; i++) {
			var chan = publicChannels[i],
				chanJson = chan.toJSON();

			// extract some non-collection information:
			chanJson.numActiveClients = chan.clients.where({idle: false}).length;
			chanJson.numClients = chan.clients.length;

			delete chanJson.topicObj;
			
			publicChannelInformation.push(chanJson);
		}

		_.sortBy(publicChannelInformation, "numActiveClients");

		res.write(JSON.stringify(publicChannelInformation));
		res.end();
	}
});

app.get("/*", function (req, res) {
	res.sendfile(index);
});

server.listen(config.host.PORT);

console.log('Listening on port', config.host.PORT);

// SocketIO init:
sio = sio.listen(server);
sio.enable('browser client minification');
sio.enable('browser client gzip');
sio.set('log level', 1);

// use db 15:
redisC.select(15, function (err, reply) {
	var ChannelStructures = require('./Channels.js').ChannelStructures(redisC, EventBus),
		ChannelModel = ChannelStructures.ServerChannelModel;

	Channels = new ChannelStructures.ChannelsCollection();

	chatServer(sio, redisC, EventBus, Channels, ChannelModel); // start up the chat server
	codeServer(sio, redisC, EventBus, Channels); // start up the code server
	drawServer(sio, redisC, EventBus, Channels); // start up the code server
	callServer(sio, redisC, EventBus, Channels);
	userServer(sio, redisC, EventBus, Channels);
});
