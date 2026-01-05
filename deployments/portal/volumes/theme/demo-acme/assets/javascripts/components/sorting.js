/*
	Sorting algorithm for the different Card view, block or inline.
	sort() is firstly saving the sorting type in local storage.
	Then the iterations within are setting 
		1) the grid system
		2) flex direction of the contents
		3) alignment of the card body title contents
		3) alignment of the card body
		4) image border radius and finally
		5) the card's properties flex direction 
		6) the card's CTA container flex direction
	respectively.
*/

function viewAsListHandler () {
  document.getElementById('view-as-cards')?.classList.remove('active')
  document.getElementById('view-as-list')?.classList.add('active')
  document.getElementById('list-svg')?.classList.add('active');
  document.getElementById('grid-svg')?.classList.remove('active');
}
function viewAsCardsHandler () {
  document.getElementById('view-as-cards')?.classList.add('active')
  document.getElementById('view-as-list')?.classList.remove('active')
  document.getElementById('list-svg')?.classList.remove('active');
  document.getElementById('grid-svg')?.classList.add('active');
}

export function SortBy(defaults) {
	let apiContainers = document.querySelectorAll(defaults.mainWrapper);
	let apiCards = document.querySelectorAll(defaults.elementWrapper);
	let apiCardsTitles = document.querySelectorAll(defaults.elementTitle);
	let apiCardBodies = document.querySelectorAll(defaults.elementContent);
	let apiCardImages = document.querySelectorAll(defaults.elementImage);
	let apiCardCtaContainer = document.querySelectorAll(defaults.elementCtaContainer);
	let apiCardCTA = document.querySelectorAll(defaults.elementCTA);
  let sort = function(type) {
  	let cardView = (type === 'viewAsCards');
  	localStorage.setItem('viewAsList', type !== 'viewAsCards');
		apiContainers.forEach(c => { cardView ? c.classList.replace('col-lg-12', 'col-lg-4') : c.classList.replace('col-lg-4', 'col-lg-12')});
		apiCards.forEach(c => { cardView ? c.classList.replace('flex-row', 'flex-column') : c.classList.replace('flex-column', 'flex-row')});
		apiCardsTitles.forEach(c => { cardView ? c.classList.replace('flex-row-reverse', 'flex-column') : c.classList.replace('flex-column', 'flex-row-reverse')});
		apiCardBodies.forEach(c => { cardView ? c.classList.replace('align-self-center', 'align-self-start') : c.classList.replace('align-self-start', 'align-self-center')});
		apiCardImages.forEach(c => { cardView ? c.classList.replace('card-image-border-list-view', 'card-image-border-card-view') : c.classList.replace('card-image-border-card-view', 'card-image-border-list-view')});
		apiCardCtaContainer.forEach(c => { cardView ? c.classList.replace('flex-column', 'flex-row') : c.classList.replace('flex-row', 'flex-column')});
    apiCardCtaContainer.forEach(c => { cardView ? c.classList.replace('w-auto', 'w-100') : c.classList.replace('w-100', 'w-auto')});
		apiCardCTA.forEach(c => { cardView ? c.classList.replace('mb-3', 'mb-0') : c.classList.replace('mb-0', 'mb-3')});
    apiCardCTA.forEach(c => { cardView ? c.classList.replace('mr-0', 'mr-2') : c.classList.replace('mr-2', 'mr-0')});
  };

  const bindEvents = () => {
    document.getElementById('view-as-cards')?.addEventListener('click', () => {
      viewAsCardsHandler()
      sort('viewAsCards');
    });
    
    document.getElementById('view-as-list')?.addEventListener('click', () => {
      viewAsListHandler()
      sort('viewAsList');
    });
  }

  let init = () => {
  	let viewAs = localStorage.getItem('viewAsList') === 'true' ? 'viewAsList' : 'viewAsCards';
    if(viewAs === 'viewAsList') {
      viewAsListHandler()
    } else {
      viewAsCardsHandler()
    }

    bindEvents();
	  sort(viewAs);
  }

  init();

  return {
    sort
  }
}

