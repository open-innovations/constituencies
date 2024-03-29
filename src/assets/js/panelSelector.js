(function(root){

	if(!root.OI) root.OI = {};
	if(!root.OI.ready){
		root.OI.ready = function(fn){
			// Version 1.1
			if(document.readyState != 'loading') fn();
			else document.addEventListener('DOMContentLoaded', fn);
		};
	}

})(window || this);

OI.ready(function(){

	// Add default CSS
	var styles = document.createElement('style');
	styles.innerHTML = `
		panelSelector { margin-bottom: 1em; }
		panelSelector [role="tablist"] {
			display: grid;
			grid-template-columns: repeat(clamp(1, var(--tab-count, 4), 4), 1fr);
			grid-gap: 4px;
			margin: 0;
			list-style: none;
		}
		panelSelector [role="tablist"] > * {
			display: inline-block;
			z-index: 1;
		}
		panelSelector [role="tab"] {
			position: relative;
			z-index: 2;
			top: 1px;
			display: block;
			text-align:center;
			padding: 0.5em;
			text-decoration: none;
			color: inherit;
			border: 1px solid #dfdfdf;
			background: #dfdfdf;
		}
		panelSelector [role="tab"][aria-selected="true"] {
			background: white;
			border-bottom-color: transparent;
		}
		panelSelector [role="tabpanel"] {
			border: 1px solid #dfdfdf;
		}`;
	document.head.prepend(styles);
	
	var panelSelectors = document.querySelectorAll('panelSelector');
	var p;
	
	function panelSelector(el){

		var type,titleSelector,position,idx,list,panel,panels,li,title,tabs,id,_obj;
		type = el.getAttribute('data-type');
		titleSelector = el.getAttribute('data-title-selector')||'h2';
		position = el.getAttribute('data-position');
		id = el.id;
		
		panels = el.querySelectorAll('[role="tabpanel"]');
		
		el.setAttribute('style','--tab-count: '+panels.length+';');

		if(type=="select") list = document.createElement('select');
		else list = document.createElement('ul');
		
		list.setAttribute('role','tablist');
		
		for(idx = 0; idx < panels.length; idx++){
			panel = panels[idx];
			if(!panel.id) panel.setAttribute('id', id+'-section'+(idx + 1));


			if(!panel.getAttribute('data-tab-title')){
				title = panel.querySelector(titleSelector).innerHTML;
				panel.setAttribute('data-tab-title',title);
			}else{
				title = panel.getAttribute('data-tab-title');
			}
			li = document.createElement('li');
			li.innerHTML = '<a href="#' + panel.id + '" role="tab" aria-controls="'+panel.id+'">' + title + '</a>';
			list.append(li);
		}
		if(position=="bottom") el.append(list);
		else el.prepend(list);
		
		_obj = this;

		if(type=="select"){
			
		}else{

			this.setTab = function(tab){
				for(t = 0; t < tabs.length; t++){
					if(tab==tabs[t]){

						// Remove all current selected tabs
						list.querySelectorAll('[aria-selected="true"]').forEach((t) => t.setAttribute("aria-selected", false));

						// Set this tab as selected
						tab.setAttribute("aria-selected", true);

						// Hide all tab panels
						panels.forEach((p) => p.setAttribute("hidden", true));

						// Show the selected panel
						el.querySelector(`#${tab.getAttribute("aria-controls")}`).removeAttribute("hidden");
					}
				}
						
			};

			tabs = el.querySelectorAll('[role="tab"]');

			// Add a click event handler to each tab
			tabs.forEach((tab) => {
				tab.addEventListener("click", function(e){ e.preventDefault(); e.stopPropagation(); _obj.setTab(e.target) });
			});

			// Enable arrow navigation between tabs in the tab list
			let tabFocus = 0;

			list.addEventListener("keydown", (e) => {
				if(e.key === "ArrowRight" || e.key === "ArrowLeft"){

					tabs[tabFocus].setAttribute("tabindex", -1);
					if(e.key === "ArrowRight"){
						// Move right
						tabFocus++;
						// If we're at the end, go to the start
						if(tabFocus >= tabs.length) tabFocus = 0;
					}else if(e.key === "ArrowLeft"){
						// Move left
						tabFocus--;
						// If we're at the start, move to the end
						if(tabFocus < 0) tabFocus = tabs.length - 1;
					}

					tabs[tabFocus].setAttribute("tabindex", 0);
					tabs[tabFocus].focus();
					this.setTab(tabs[tabFocus]);
				}
			});
			this.setTab(tabs[0]);
		}

		return this;
	}
	for(p = 0; p < panelSelectors.length; p++) new panelSelector(panelSelectors[p]);
});