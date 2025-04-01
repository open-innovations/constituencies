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
	if(typeof conf.data==="string"){
		// Are we referencing local data in a release sub-directory?
		if(conf.data.indexOf('release.')==0){
			let release = conf.data.substr(8);
			if(conf.dataRows){
				conf.data = conf.dataRows;
			}else{
				conf.data = input.page.data.release[release];
			}
			conf.attribution += '<div class="menu-item CSV"><a href="' + release.replace(/\./g,"\/") + ".csv" + '">CSV</a></div>'
		}
		// If we are referencing local data (without "." separators),
		// we need to pass in "page" to the component.
		if(conf.dataRows){
			conf.data = conf.dataRows;
		}else{
			if(typeof conf.data==="string" && conf.data.indexOf('.') < 0){
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
	}else{
		if(conf.dataRows) conf.data = conf.dataRows;
	}
	if(api.file) conf.attribution += '<div class="menu-item JSON"><a href="'+api.file+'.json" aria-label="'+api.title+' as JSON">JSON</a></div>';
	conf.attribution += '</div>'
	if(!conf.boundaries){
		conf.boundaries = {
			"country": {
				"stroke": "white",
				"stroke-width": 1.5,
				"stroke-linecap": "round"
			},
			"region": "country"
		};
	}

	str += component({'config':conf});
	
	return str;
}
