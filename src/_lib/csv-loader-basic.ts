const HEADER_SEPARATOR = "---";
const NAME_JOINER = "→";

/**
 * Minimal version of CSVLoaderResult
 */
export type CSVLoaderResultBasic = Pick<
  CSVLoaderResult,
  "rows"
>;

/**
 * Tests if a value could be numeric
 */
export function isNumeric(value: number | string): boolean {
  return !isNaN(value as number);
}

function CSVToArray (CSV_string, delimiter) {
	CSV_string = CSV_string.replace(/[\n\r]+$/g,"");
	delimiter = (delimiter || ",");
	var pattern = new RegExp(("(\\" + delimiter + "|\\r?\\n|\\r|^)" + "(?:\"([^\"]*(?:\"\"[^\"]*)*)\"|" + "([^\"\\" + delimiter + "\\r\\n]*))"), "gi");
	var rows = [[]];
	var matches = false;
	while(matches = pattern.exec( CSV_string )){
		var matched_delimiter = matches[1];
		if(matched_delimiter.length && matched_delimiter !== delimiter) rows.push([]);
		var matched_value;
		matched_value = (matches[2]) ? matches[2].replace(new RegExp( "\"\"", "g" ), "\"") : matches[3];
		rows[rows.length - 1].push(matched_value||"");
	}
	return rows;
}

function ArrayToRows (array){
	var r,c,s,v,rows,head;

	// Create empty header
	head = new Array(array[0].length);
	for(c = 0; c < head.length; c++) head[c] = "";

	// Find header separator in first column
	var headerRowCount = 1;
	var bodyStart = 1;
	for(r = 1; r < array.length; r++){
		if(array[r][0]==HEADER_SEPARATOR){
			headerRowCount = r;
			bodyStart = r+1;
			continue;
		}
	}

	// Build headers
	// Subsequent column values are concatenated with NAME_JOINER
	for(r = 0; r < headerRowCount; r++){
		for(c = 0; c < array[r].length; c++){
			head[c] += (head[c] && array[r][c] ? NAME_JOINER : "") + array[r][c];
		}
	}

	// Build rows
	rows = new Array(array.length - bodyStart);
	for(r = bodyStart,s = 0; r < array.length; r++, s++){
		rows[s] = {};
		for(c = 0; c < array[r].length; c++){
			v = array[r][c];
			if(isNumeric(v)){
				rows[s][head[c]] = parseFloat(v);
			}else{
				rows[s][head[c]] = v||"";
			}
		}
	}

	return rows;
}
/**
 * Loads CSV specified at path into CSV data structure.
 *
 * This is a Lume processor.
 *
 * ```js
 * import csvLoaderBasic from './csv-loader.ts';
 * site.loadData(['.csv'], csvLoaderBasic);
 * ```
 */
export default function csvLoaderBasic(): (path: string) => Promise<CSVLoaderResultBasic> {

	return async (path: string) => {
		const text = await Deno.readTextFile(path);
		const raw = CSVToArray(text);
		const rows = ArrayToRows(raw);
		return {
			rows,
		};
	};
}
