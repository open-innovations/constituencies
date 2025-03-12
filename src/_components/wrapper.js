export default function (input) {
	const { component, config, download } = input;
	let conf = JSON.parse(JSON.stringify(config));
	let api = {'file':'','title':''};

	if(typeof conf==="string"){
		// It looks as though we've passed a string reference to an object
		if(input.page){
			if(conf in input.page.data){
				api.file = conf;
				api.title = input.page.data[conf].title;
				// Get a copy of the config
				conf = JSON.parse(JSON.stringify(input.page.data[conf].config));
			}else{
				throw new Error("Config passed as string but it doesn't exist in \"page.data\".");
			}
		}else{
			throw new Error("Config passed as string but no \"page\" passed.");
		}
	}

	let str = '';
	const dataPath = '/data';

	if(typeof conf.attribution!=="string") conf.attribution = "";
	if(conf.hexjson=="hexjson.constituencies") conf.attribution += (conf.attribution ? ' / ' : '')+'<a href="https://open-innovations.org/projects/hexmaps/hexjson">Hex layout</a>: <a href="https://github.com/odileeds/hexmaps/blob/gh-pages/maps/constituencies.hexjson">2010 constituencies</a> (Open Innovations and contributors)';
	if(conf.hexjson=="hexjson.uk-constituencies-2024") conf.attribution += (conf.attribution ? ' / ' : '')+'<a href="https://open-innovations.org/projects/hexmaps/hexjson">Hex layout</a>: <a href="https://github.com/odileeds/hexmaps/blob/gh-pages/maps/uk-constituencies-2023.hexjson">2024 constituencies</a> (Open Innovations and contributors)';
	if(conf.hexjson=="hexjson.uk-constituencies-2023-temporary") conf.attribution += (conf.attribution ? ' / ' : '')+'<a href="https://github.com/open-innovations/constituencies/blob/main/src/_data/hexjson/uk-constituencies-2023-temporary.hexjson">2024 constituencies</a> (Open Innovations and contributors)';

	conf.attribution += '<div class="menu" data-dependencies="/assets/js/menu.js">';
	if(api.file) conf.attribution += '<div class="menu-item JSON"><a href="'+api.file+'.json" aria-label="'+api.title+' as JSON">JSON</a></div>';
	if(typeof conf.data==="string"){
		if(download && typeof download.text=="string"){
		//	conf.attribution += '<div class="menu-item">'+dataPath+'<a href="' + dataPath + '/'+ conf.data.replace(/\./g,"\/").replace(/^sources\//,"")+".csv" + '" class="download"><svg xmlns="http://www.w3.org/2000/svg" width="1em" height="1em" fill="currentColor" viewBox="0 0 16 16"><path d="M.5 9.9a.5.5 0 0 1 .5.5v2.5a1 1 0 0 0 1 1h12a1 1 0 0 0 1-1v-2.5a.5.5 0 0 1 1 0v2.5a2 2 0 0 1-2 2H2a2 2 0 0 1-2-2v-2.5a.5.5 0 0 1 .5-.5z"/><path d="M7.646 11.854a.5.5 0 0 0 .708 0l3-3a.5.5 0 0 0-.708-.708L8.5 10.293V1.5a.5.5 0 0 0-1 0v8.793L5.354 8.146a.5.5 0 1 0-.708.708l3 3z"/></svg>'+ download.text + (download.type ? ' ('+download.type+')':'')+'</a></div>';
		}
		// If we are referencing local data (without "." separators),
		// we need to pass in "page" to the component.
		if(conf.data.indexOf('.') < 0){
			if(input.page){
				if(!(conf.data in input.page.data)){
					throw new Error("Unable to find "+conf.data+" in page");
				}else{
					conf.data = input.page.data[conf.data];
				} 
			}else{
				throw new Error("Data is set to \""+conf.data+"\" but no \"page\" data is provided.");
			}
		}
	}
	conf.attribution += '</div>'

	str += component({'config':conf});
	
	return str;
}
