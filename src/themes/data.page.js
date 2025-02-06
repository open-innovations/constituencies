import site from '../../_config.ts';

function resolveData(ref,context){
	let result = context;
	for (const key of ref.split('.')) result = result[key];
	return result;
}

export default function*({search}){
	
	const pages = search.pages("datafiles!=undefined");
	let index = {
		"notes": "This is an experimental API for the Open Innovations Consitituency Data site",
		"themes": {}
	};

	for(const page of pages){

		const datafiles = page.datafiles;
		const url = page.url;
		const theme = page.theme;
		for(const id of datafiles){
			console.log(theme,id,url+id+'.json');

			const config = {...page[id].config};
			const data = {};

			data.notes = "This is an experimental API for the Open Innovations Consitituency Data site";
			data.title = page[id].title;
			data.key = config.matchKey;
			data.value = config.value;
			
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
				data.data.constituencies[data.data.rows[r][data.key]] = data.data.rows[r];
			}
			delete data.data.rows;

			//if("tools" in config && "slider" in config.tools) data.values = config.tools.slider.columns;
			
			if(config.hexjson=="hexjson.constituencies"){
				data.hexjson = {
					"url":"https://open-innovations.org/projects/hexmaps/maps/constituencies.hexjson",
					"attribution": '<a href="https://open-innovations.org/projects/hexmaps/maps/constituencies.hexjson">2010 constituencies</a> (Open Innovations and contributors)'
				};
			}else if(config.hexjson=="hexjson.uk-constituencies-2024" || config.hexjson=="hexjson.uk-constituencies-2023-temporary"){
				data.hexjson = {
					"url": "https://open-innovations.org/projects/hexmaps/maps/uk-constituencies-2023.hexjson",
					"attribution": '<a href="https://open-innovations.org/projects/hexmaps/maps/uk-constituencies-2023.hexjson">2024 constituencies</a> (Open Innovations and contributors)'
				}
			}else{
				data.hexjson = {"url":data.hexjson};
			}

			data.scale = {};
			//if("scale" in config) data.scale.type = config.scale;
			if("min" in config) data.scale.min = config.min;
			if("max" in config) data.scale.max = config.max;


			data.legend = config.legend;

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