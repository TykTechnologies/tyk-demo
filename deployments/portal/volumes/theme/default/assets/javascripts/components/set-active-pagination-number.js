/*
  Accepts two parameters
    a) page number
    b) page link items , ie the `<a>`s

  It will fetch the page number from the URL param ie ?page=2 and it will activate the number 2 of the pagination items.
  If there is no URL param it will activate the number 1
*/

export function ActivePageNumber(defaults) {
  const params = new URLSearchParams(window.location.search);
  const currentPageNumber = params.get(defaults.searchParam);
  let paginationLinks = document.querySelectorAll(defaults.paginationLink);

  paginationLinks.forEach(l => l.classList.remove('current-page'));
  paginationLinks[currentPageNumber ?? 0]?.classList.add('current-page');
}