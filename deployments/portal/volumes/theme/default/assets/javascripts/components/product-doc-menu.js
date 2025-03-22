
export function SelectDocMenuItem(docMenu) {
	const contentPrefix = "product-doc-content";
	const menuPrefix = "prod-doc-menu";

	let extractId = (elemId) => {
		if (elemId !== null) {
			return elemId.split("_")[1];
		}
	}

	let toggleContent = (id) => {
		let docEl = document.getElementById(contentPrefix + "_" + id);
		Array.from(document.getElementsByClassName(contentPrefix)).forEach(del => {
			del.classList.add("d-none");
		});
		docEl.classList.remove("d-none");
	};

	let toggleMenu = (id) => {
		Array.from(docMenu.item(0).querySelectorAll('a')).forEach(del => {
			del.classList.remove("product-doc-menu-active");
			del.classList.add("product-doc-menu");
		});
		let menuEl = document.getElementById(menuPrefix + "_" + id);
		menuEl.classList.add("product-doc-menu-active");
		menuEl.classList.remove("product-doc-menu");
	};

	if (docMenu != null) {
		if (docMenu.length > 0) {
			let els = docMenu.item(0).querySelectorAll('a')
			let firstId = extractId(els.item(0).id)
			// set all contents to none but the first
			toggleContent(firstId);
			// set all menus unselected but the first
			toggleMenu(firstId)

			Array.from(els).forEach(el => {
				el.addEventListener("click", ev => {
					ev.preventDefault();
					let id = extractId(ev.target.id);
					toggleContent(id);
					toggleMenu(id);
				});
			});
		}
	}
}
