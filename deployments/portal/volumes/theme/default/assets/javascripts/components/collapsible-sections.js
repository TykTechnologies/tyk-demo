export function CollapsibleSections({triggerElements, collapsibleID}) {
  triggerElements.forEach((el, i) => {
    el.addEventListener('click', () => {
      let index = i - 1
      if (i == 0) {
        index = triggerElements.length - 1
      }
      $(`${collapsibleID}-${index}`).on('show.bs.collapse', () => {
        const arrowUp = el.querySelector('.arrow-up-tyk');
        const arrowDown = el.querySelector('.arrow-down-tyk');
        arrowDown?.classList.replace('d-none', 'd-inline');
        arrowUp?.classList.replace('d-inline', 'd-none');
      });

      $(`${collapsibleID}-${index}`).on('hide.bs.collapse', () => {
        const arrowUp = el.querySelector('.arrow-up-tyk');
        const arrowDown = el.querySelector('.arrow-down-tyk');
        arrowDown?.classList.replace('d-inline', 'd-none');
        arrowUp?.classList.replace('d-none', 'd-inline');
      });
    });
  });
}