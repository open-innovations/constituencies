import site from '../../_config.ts';

function resolveData(ref,context){
	let result = context;
	for (const key of ref.split('.')) result = result[key];
	return result;
}

export default function*({search}){
	
	const pages = search.pages("datafiles!=undefined");
	let index = {};

	for(const page of pages){

		const datafiles = page.datafiles;
		const url = page.url;
		const theme = page.theme;
		for(const id of datafiles){
			console.log(theme,id,url+id+'.json');

			const config = {...page[id].config};
			const data = {};
			
			data.key = config.matchKey;
			data.value = config.value;

			if(config.data in page){
				// We have the data in the page
				data.data = page[config.data].rows;
			}else{
				// See if the data is nested in the page
				data.data = resolveData(config.data,page);
			}

			//if("tools" in config && "slider" in config.tools) data.values = config.tools.slider.columns;
			
			data.scale = {};
			//if("scale" in config) data.scale.type = config.scale;
			if("min" in config) data.scale.min = config.min;
			if("max" in config) data.scale.max = config.max;

			if(config.hexjson=="hexjson.constituencies"){
				data.hexjson = "https://open-innovations.org/projects/hexmaps/maps/constituencies.hexjson";
				data.attribution = config.attribution + (config.attribution ? ' / ' : '') + '<a href="https://open-innovations.org/projects/hexmaps/hexjson">Hex layout</a>: <a href="https://open-innovations.org/projects/hexmaps/maps/constituencies.hexjson">2010 constituencies</a> (Open Innovations and contributors)';
			}else if(config.hexjson=="hexjson.uk-constituencies-2024" || config.hexjson=="hexjson.uk-constituencies-2023-temporary"){
				data.hexjson = "https://open-innovations.org/projects/hexmaps/maps/uk-constituencies-2023.hexjson";
				data.attribution = config.attribution + (config.attribution ? ' / ' : '') + '<a href="https://open-innovations.org/projects/hexmaps/hexjson">Hex layout</a>: <a href="https://open-innovations.org/projects/hexmaps/maps/uk-constituencies-2023.hexjson">2024 constituencies</a> (Open Innovations and contributors)';
			}
			data.legend = config.legend;

			// Add to themes
			if(!(page.theme in index)){
				index[page.theme] = {
					'title':page.themes[page.theme].title,
					'description':page.themes[page.theme].description,
					'data':[]
				};
			}

			const pageurl = url+id+'.json';

			index[page.theme].data.push({'url':site.url(pageurl, true),'title':(page[id].title||""),'attribution':config.attribution});
			
			yield {'url':pageurl,'content':niceJSON(data)};
		}
	}

	yield {'url':'./index.json','content':niceJSON(index,3)};	
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