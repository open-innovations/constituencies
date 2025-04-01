export function buildSpending(data,matchKey){

	var rows = [];
	var lookup = {};
	var key,value,r,pcon,row,t,str,c;
	for(r = 0; r < data.rows.length; r++){
		if(typeof data.rows[r]['Candidate\'s position']==="number"){
			pcon = data.rows[r][matchKey];
			if(!(pcon in lookup)){
				lookup[pcon] = rows.length;
				rows.push({'total':0,'candidates':[]});
			}
			rows[lookup[pcon]][matchKey] = pcon;
			t = 0;
			if(typeof data.rows[r]['Total reported spending']==="number" && !isNaN(data.rows[r]['Total reported spending'])) t = data.rows[r]['Total reported spending'];
			rows[lookup[pcon]].total += t;
			rows[lookup[pcon]].candidates.push({
				'name':data.rows[r]['Forename']+" "+data.rows[r]['Surname'],
				'party':data.rows[r]['Candidate\'s party'].replace(/ $/,''),
				'total':t,
				'share':data.rows[r]['Candidate\'s vote-share'],
				'position':data.rows[r]['Candidate\'s position']
			});
		}
	}

	for(r = 0; r < rows.length; r++){
		rows[r].total = parseFloat(rows[r].total.toFixed(2));
		str = "Name / Party / Vote share / Spending";
		rows[r].candidates.sort((a, b) => (a.position - b.position));
		for(c = 0; c < rows[r].candidates.length; c++){
			str += (str ? "\n" : "")+(rows[r].candidates[c].name||"")+" / "+rows[r].candidates[c].party+" / "+rows[r].candidates[c].share+"% / &pound;"+(rows[r].candidates[c].total).toLocaleString();
		}
		rows[r].candidates = str;
	}
	return rows;
}
