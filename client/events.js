//TODO: more namespacing
window.EventBus = _.clone(Backbone.Events);
window.EventBus.on("message",function(socket,client,msg){
	console.log("Message event called");
});
window.EventBus.on("speak",function(socket,client,msg){
	console.log("Speak Event called");
	msg.body = "STAHP";
});
