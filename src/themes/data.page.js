import site from '../../_config.ts';
import { expandGlobSync } from "lume/deps/fs.ts";

function resolveData(ref,context){
	let result = context;
	for (const key of ref.split('.')) result = result[key];
	return result;
}

export default function*({search,themes}){

	const notes = "This is an experimental API for the Open Innovations Consitituency Data site. The format is not finalised yet and is likely to change. Be very careful about relying on it for now. Feedback on how we could improve it is welcome hello@open-innovations.org";
	const pages = search.pages("api!=undefined");
	let index = {
		"notes": notes,
		"themes": {}
	};
	for(let theme in themes){
		index.themes[theme] = {
			'title':themes[theme].title,
			'description':themes[theme].description,
			'visualisations':[]
		};
	}

	for(const page of pages){

		const api = page.api;
		const url = page.url;
		const theme = page.theme;
		for(const id of api){
			console.log(theme,id,url+id+'.json');

			const config = {...page[id].config};
			const data = {};

			data.notes = notes;
			data.title = page[id].title;
			data.key = config.matchKey;
			data.value = ("tools" in config && "slider" in config.tools && "columns" in config.tools.slider) ? config.tools.slider.columns : [config.value];
			
			let hexjson = getObject(config.hexjson,page);

			if(config.hexjson=="hexjson.constituencies"){
				data.hexjson = {
					"url":"https://open-innovations.org/projects/hexmaps/maps/constituencies.hexjson",
					"attribution": '<a href="https://open-innovations.org/projects/hexmaps/maps/constituencies.hexjson">2010 constituencies</a> (Open Innovations and contributors)'
				};
			}else if(config.hexjson=="hexjson.uk-constituencies-2024"){
				data.hexjson = {
					"url": "https://open-innovations.org/projects/hexmaps/maps/uk-constituencies-2023.hexjson",
					"attribution": '<a href="https://open-innovations.org/projects/hexmaps/maps/uk-constituencies-2023.hexjson">2024 constituencies</a> (Open Innovations and contributors)'
				}
			}else if(config.hexjson=="hexjson.uk-constituencies-2023-temporary"){
				data.hexjson = {
					"url": "https://raw.githubusercontent.com/open-innovations/constituencies/refs/heads/main/src/_data/hexjson/uk-constituencies-2023-temporary.hexjson",
					"attribution": '<a href="https://raw.githubusercontent.com/open-innovations/constituencies/refs/heads/main/src/_data/hexjson/uk-constituencies-2023-temporary.hexjson">2024 constituencies</a> (Open Innovations and contributors)'
				}
			}else{
				data.hexjson = {"url":data.hexjson};
			}

			data.data = {};
			data.data.attribution = config.attribution.replace(/^Data: ?/,'');
			if(config.data in page){
				// We have the data in the page
				data.data.rows = page[config.data].rows;
			}else{
				// See if the data is nested in the page
				data.data.rows = resolveData(config.data,page).rows;
			}
			data.data.constituencies = {};
			for(let r = 0; r < data.data.rows.length; r++){
				// Only include it if the code is in the HexJSON
				let code = data.data.rows[r][data.key];
				if(code in hexjson.hexes) data.data.constituencies[code] = data.data.rows[r];
			}
			delete data.data.rows;

			//if("tools" in config && "slider" in config.tools) data.values = config.tools.slider.columns;

			data.scale = {};
			//if("scale" in config) data.scale.type = config.scale;
			if("min" in config) data.scale.min = config.min;
			if("max" in config) data.scale.max = config.max;


			data.legend = config.legend;

			if("date" in page[id]){
				data.data.date = page[id].date;
			}

			data.data.virtualColumns = config.columns;

			if("units" in page[id]){
				data.units = {...page[id].units};
			}

			// Add to themes
			if(!(page.theme in index.themes)){
				index.themes[page.theme] = {
					'title':page.themes[page.theme].title,
					'description':page.themes[page.theme].description,
					'visualisations':[]
				};
			}

			const pageurl = url+id+'.json';

			index.themes[page.theme].visualisations.push({'url':site.url(pageurl, true),'title':(page[id].title||""),'attribution':config.attribution});
			
			yield {'url':pageurl,'content':niceJSON(data,2)};
		}
	}
	
	for(let theme in index.themes){
		index.themes[theme].visualisations.sort((a,b) => (a.title > b.title ? 1 : (b.title > a.title ? -1 : 0)));
	}

	yield {'url':'./index.json','content':niceJSON(index,4)};	
}

function escapeRegExp(string){
    return string.replace(/([.*+?^=!:${}()|\[\]\/\\])/g, "\\$1");
}

// Format JSON so that it is nicely indented at a particular depth
function niceJSON(data,depth=1){
	let content = JSON.stringify(data,null,"\t");
	content = content.replace(new RegExp('[\n]\t{'+(depth+1)+',}', "g"),'');
	content = content.replace(new RegExp('[\n]\t{'+(depth)+'}(\}|\])(\,|\n)', "g"),function(m,p1,p2){ return p1+p2; });
	return content;
}

function getObject(str,obj){
	if(str in obj) return obj[str];
	let idx = str.indexOf('.');
	if(idx > 0){
		let key = str.substring(0,idx);
		let rest = str.substring(idx+1);
		if(key in obj) return getObject(rest,obj[key]);
	}
	return null;
}