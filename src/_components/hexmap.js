export default function ({ comp, config, download }) {
	return comp.wrapper({'comp':comp,'component':comp.oi.map.hex_cartogram,'config':config,'download':download});
}
