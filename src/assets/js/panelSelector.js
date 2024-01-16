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
	var p,type,titleSelector,position,idx,list,panel,panels,li,title,tabs,id;
	
	for(p = 0; p < panelSelectors.length; p++){
		
		type = panelSelectors[p],panelSelectors[p].getAttribute('data-type');
		titleSelector = panelSelectors[p].getAttribute('data-title-selector')||'h2';
		position = panelSelectors[p].getAttribute('data-position');
		id = panelSelectors[p].id;
		
		panels = panelSelectors[p].querySelectorAll('[role="tabpanel"]');
		
		panelSelectors[p].setAttribute('style','--tab-count: '+panels.length+';');

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
		if(position=="bottom") panelSelectors[p].append(list);
		else panelSelectors[p].prepend(list);
		
		
		if(type=="select"){
			
		}else{

			tabs = document.querySelectorAll('[role="tab"]');

			// Add a click event handler to each tab
			tabs.forEach((tab) => {
				tab.addEventListener("click", function(e){ e.preventDefault(); e.stopPropagation(); changeTabs(e.target) });
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
					changeTabs(tabs[tabFocus]);
				}
			});
			changeTabs(tabs[0]);
		}
	}
	function changeTabs(tab) {
		const list = tab.closest('[role=tablist]');
		const container = tab.closest('panelSelector');

		// Remove all current selected tabs
		list
		.querySelectorAll('[aria-selected="true"]')
		.forEach((t) => t.setAttribute("aria-selected", false));

		// Set this tab as selected
		tab.setAttribute("aria-selected", true);

		// Hide all tab panels
		container
		.querySelectorAll('[role="tabpanel"]')
		.forEach((p) => p.setAttribute("hidden", true));

		// Show the selected panel
		container.querySelector(`#${tab.getAttribute("aria-controls")}`)
		.removeAttribute("hidden");
	}
});