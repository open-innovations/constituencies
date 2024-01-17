export default function ({ comp, component, config, download }) {

	let str = '';
	const dataPath = '/data';

	if(!config.attribution) config.attribution = "";
	if(config.hexjson=="hexjson.constituencies") config.attribution += '<br /><a href="https://open-innovations.org/projects/hexmaps/hexjson">Hex layout</a>: <a href="https://github.com/odileeds/hexmaps/blob/gh-pages/maps/constituencies.hexjson">2010 constituencies</a> (Open Innovations and contributors)';
	if(config.hexjson=="hexjson.uk-constituencies-2023" || config.hexjson=="hexjson.uk-constituencies-2023-temporary") config.attribution += '<br /><a href="https://open-innovations.org/projects/hexmaps/hexjson">Hex layout</a>: <a href="https://github.com/odileeds/hexmaps/blob/gh-pages/maps/uk-constituencies-2023.hexjson">2023 constituencies</a> (Open Innovations and contributors)';

	config.attribution += '<div class="menu" data-dependencies="/assets/js/menu.js">';
	if(typeof config.data==="string"){
		if(download && typeof download.text=="string"){
			config.attribution += '<div class="menu-item">Download: <a href="' + dataPath + '/'+ config.data.replace(/\./g,"\/")+".csv" + '" class="download">'+ download.text + (download.type ? ' ('+download.type+')':'')+'<svg xmlns="http://www.w3.org/2000/svg" width="1em" height="1em" fill="currentColor" viewBox="0 0 16 16"><path d="M.5 9.9a.5.5 0 0 1 .5.5v2.5a1 1 0 0 0 1 1h12a1 1 0 0 0 1-1v-2.5a.5.5 0 0 1 1 0v2.5a2 2 0 0 1-2 2H2a2 2 0 0 1-2-2v-2.5a.5.5 0 0 1 .5-.5z"/><path d="M7.646 11.854a.5.5 0 0 0 .708 0l3-3a.5.5 0 0 0-.708-.708L8.5 10.293V1.5a.5.5 0 0 0-1 0v8.793L5.354 8.146a.5.5 0 1 0-.708.708l3 3z"/></svg></a></div>';
		}
	}
	config.attribution += '</div>'

	str += component({'config':config});
	
	return str;
}
