export default function*({search}){
	
	const pages = search.pages("datafiles!=undefined");

	for(const page of pages){
		
		const datafiles = page.datafiles;
		const url = page.url;
		for(const id of datafiles){
			console.log(id,url+id+'.json');
			const data = {};
			
			data.key = page[id].matchKey;
			data.value = page[id].value;
			data.data = page[page[id].data].rows;

			//if("tools" in page[id] && "slider" in page[id].tools) data.values = page[id].tools.slider.columns;
			
			data.scale = {};
			//if("scale" in page[id]) data.scale.type = page[id].scale;
			if("min" in page[id]) data.scale.min = page[id].min;
			if("max" in page[id]) data.scale.max = page[id].max;

			if(page[id].hexjson=="hexjson.constituencies"){
				data.hexjson = "https://open-innovations.org/projects/hexmaps/maps/constituencies.hexjson";
				data.attribution = page[id].attribution + (page[id].attribution ? ' / ' : '') + '<a href="https://open-innovations.org/projects/hexmaps/hexjson">Hex layout</a>: <a href="https://open-innovations.org/projects/hexmaps/maps/constituencies.hexjson">2010 constituencies</a> (Open Innovations and contributors)';
			}else if(page[id].hexjson=="hexjson.uk-constituencies-2024" || page[id].hexjson=="hexjson.uk-constituencies-2023-temporary"){
				data.hexjson = "https://open-innovations.org/projects/hexmaps/maps/uk-constituencies-2023.hexjson";
				data.attribution = page[id].attribution + (page[id].attribution ? ' / ' : '') + '<a href="https://open-innovations.org/projects/hexmaps/hexjson">Hex layout</a>: <a href="https://open-innovations.org/projects/hexmaps/maps/uk-constituencies-2023.hexjson">2024 constituencies</a> (Open Innovations and contributors)';
			}
			data.legend = page[id].legend;

			// Format nicely
			let content = JSON.stringify(data,null,"\t");
			content = content.replace(/[\n\r]\t{2,}/g,'');
			content = content.replace(/\n\t{1}([\}\]])(\,|\n)/g,function(m,p1,p2){ return p1+p2; });
			
			yield {'url':url+id+'.json','content':content};
		}
		
	}

	
}