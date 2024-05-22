export function buildLegend(data,column,labels={}){

	var lookup = {};
	for(let r = 0; r < data.rows.length; r++){
		let v = data.rows[r][column];
		if(v){
			if(!lookup[v]) lookup[v] = 0;
			lookup[v]++;
		}
	}

	let legend = [];
	for(var party in lookup){
		legend.push({'colour':party,'count':lookup[party],'label':(party in labels ? labels[party] : party)+' / '+lookup[party]});
	}
	legend.sort(function(a, b){
		if(a.colour=="Spk") return -1;
		if(b.colour=="Spk") return 1;
		// Sort by count
		if(a.count - b.count != 0) return (a.count - b.count);
		// Fall back to sorting by label
		return (a.label.toLowerCase() < b.label.toLowerCase() ? 1 : -1);
	});

	return legend;
}
