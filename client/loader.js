define(function(require,exports,module){
	var _ = require('underscore'),
		$ = require('jquery'),
		config = module.config();
		mods = [];

	var section = _.template($('#sectionTemplate').html()),
		button = _.template($('#buttonTemplate').html());
	_.each(config.modules,function(val){
		val = _.defaults(val,{active: false});

		var s = $(section(val)).appendTo($('#panes'));
		if (!val.active) s.hide();
		$(button(val)).appendTo($('#buttons'));
		mods.push(_.extend(val,{
			view: 'modules/'+val.name+'/client'
		}));
	});
	//Preload modules
	require(_.map(mods,function(mod){ return mod.view; }),function(){});
	return mods;
});