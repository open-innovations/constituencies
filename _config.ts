import lume from "lume/mod.ts";
import nunjucks from "lume/plugins/nunjucks.ts";	// Lume 2.0 requires us to add Nunjucks
import base_path from "lume/plugins/base_path.ts";
import date from "lume/plugins/date.ts";
import metas from "lume/plugins/metas.ts";
import postcss from "lume/plugins/postcss.ts";
import { walkSync } from 'std/fs/mod.ts';
import sitemap from "lume/plugins/sitemap.ts";		// To build a site map
import { expandGlobSync } from "lume/deps/fs.ts";

// Importing the OI Lume charts and utilities
import oiViz from "https://deno.land/x/oi_lume_viz@v0.18.4/mod.ts";
import autoDependency from "https://deno.land/x/oi_lume_utils@v0.4.0/processors/auto-dependency.ts";
import csvLoaderBasic from "./src/_lib/csv-loader-basic.ts";
import jsonLoader from "lume/core/loaders/json.ts";


const site = lume({
  src: './src',
  // TODO Update this with the proper URL
  location: new URL("https://constituencies.open-innovations.org/"),
});

site.use(nunjucks());
site.use(sitemap({
	query: "!draft"
}));

// Register a series of extensions to be loaded by the OI CSV loader
// https://lume.land/docs/core/loaders/
site.loadData([".csv", ".tsv", ".dat"], csvLoaderBasic());
site.loadData([".geojson"], jsonLoader);
site.loadData([".hexjson"], jsonLoader);

/**
 * Descend into a folder tree and remotely map each file to the Lume build
 * 
 * @param {string} source Source directory, relative to this file
 * @param {string} target Location in the lume build virtual file system
 */
function remoteTree(source, target) {
  const files = Array.from(walkSync(source, {
    includeDirs: false,
  })).map(({ path }) => path);

  files.forEach(remote => {
    const local = remote.replace(source, target);
    site.remoteFile(local, './' + remote);
  });
}
const dataPath = '/data';
// Mirror source data files to live site
remoteTree('src/_data/sources', dataPath);
// Copy /data to live site
site.copy(dataPath);

// Mirror source data files to live site
remoteTree('src/_data/hexjson', '/assets/hexjson/');
// Copy /data to live site
site.copy('/assets/hexjson/');
site.copy([".png"]);

// Register an HTML processor
// https://lume.land/docs/core/processors/
site.process([".html"], (pages) => pages.forEach(autoDependency));


site.loadAssets([".css"]);
site.loadAssets([".js"]);
//site.loadAssets([".svg"]);
site.loadAssets([".hexjson"]);

// Import lume viz
import oiVizConfig from "./oi-viz-config.ts";
site.use(oiViz(oiVizConfig));

// Add filters
site.filter('match', (value, regex) => { const re = new RegExp(regex); return value.match(re); });
site.filter('keys', o => Object.keys(o) );

site.use(metas({
  defaultPageData: {
    title: 'title', // Use the `date` value as fallback.
  },
}));
site.use(date());
site.use(postcss({}));

// This should normally run late on, as it registers a processor which re-writes URLs.
// These could be updated by prior processors.
site.use(base_path());

site.copy('CNAME');
site.copy('.nojekyll');
site.copy('/assets/css/fonts/');


// Copy over any "_data/release/*.csv" files
const csvFiles = expandGlobSync('src/**/_data/release/**/*.csv').map(f => f.path);
csvFiles.forEach((file: string) => {
    const remote = import.meta.resolve(file);
    const local = file.replace(site.src() + '/', '').replace('_data/release/', '');
    // console.debug({ local, remote });
    site.remoteFile(local, remote);
})
site.copy(['.csv']);

export default site;
