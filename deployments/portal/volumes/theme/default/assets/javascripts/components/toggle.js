/*
  Toggle func() can be used to:
    1. Handle interactive actions , as used in the Home page
    2. Switch between different contents, as used in the "Profile" page to edit profile details.
*/

function toggleSections(contentToHide, contentToDisplay) {
  contentToHide?.classList?.replace('d-block', 'd-none');
  contentToDisplay?.classList?.replace('d-none', 'd-block');
}

function interactive(options) {
  let indexToDisplay = options.clickedElementIndex + 1;
  let contentToDisplay = document.querySelector(`.${options.defaultValues.content}.${options.defaultValues.contentPrefix + indexToDisplay}`);
  let contentToHide = document.querySelector(`.${options.defaultValues.content}.d-block`);
  let activeItem = document.querySelector(`.${options.defaultValues.clickableElement}.active`);

  activeItem.classList.remove('active');
  options.el.classList.add('active');
  toggleSections(contentToHide, contentToDisplay);

}

function disableAllOtherEditButtons(allOtherSections, method) {
  Array.from(allOtherSections).forEach(s => {
    if(!s.querySelector('.enable-editing')) return;
    s.querySelector('.enable-editing')[method === 'show' ? 'setAttribute' : 'removeAttribute']('disabled', "");
  });
}

function show(options) {
  let indexToHide = options.clickedElementIndex * 2;
  let indexToDisplay = indexToHide + 1;
  let contentToDisplay = document.querySelector(`.${options.defaultValues.content}.${options.defaultValues.contentPrefix + indexToDisplay}`);
  let contentToHide = document.querySelector(`.${options.defaultValues.content}.d-block`);
  
  options.enableEdit?.classList?.replace('d-block', 'd-none');
  options.disableEdit?.classList?.replace('d-none', 'd-block');
  disableAllOtherEditButtons(options.allOtherSections, 'show');
  toggleSections(contentToHide, contentToDisplay);

}
function hide(options) {
  let indexToDisplay = options.clickedElementIndex * 2;
  let indexToHide = indexToDisplay + 1;
  let contentToDisplay = options.currentSection.querySelector(`.${options.defaultValues.content}.${options.defaultValues.contentPrefix + indexToDisplay}`);
  let contentToHide = options.currentSection.querySelector(`.${options.defaultValues.content}.${options.defaultValues.contentPrefix + indexToHide}`);

  options.enableEdit?.classList?.replace('d-none', 'd-block');
  options.disableEdit?.classList?.replace('d-block', 'd-none');
  disableAllOtherEditButtons(options.allOtherSections, 'hide');
  toggleSections(contentToHide, contentToDisplay);

}

export function toggle(elements, defaultValues, method, isInteractive) {
  Array.from(elements).forEach(el => {
    el.addEventListener('click', function(e) {
    let clickedElementIndex = Array.from(elements).indexOf(e.target);
    let currentSection = document.querySelector(`.${defaultValues.section}-${clickedElementIndex + 1}`);
    let allOtherSections =  document.querySelectorAll(`.profile-wrapper__card-section:not(.${defaultValues.section}-${clickedElementIndex + 1})`);
    let enableEdit = currentSection?.querySelector(`.enable-editing.${method === 'show' ? 'd-block' : 'd-none'}`);
    let disableEdit = currentSection?.querySelector(`.edit-cta.${method === 'show' ? 'd-none' : 'd-block'}`);

    let methodOptions = {
      clickedElementIndex,
      currentSection,
      allOtherSections,
      enableEdit,
      disableEdit,
      defaultValues,
      el
    }
    if(isInteractive) {
      interactive(methodOptions);
    } else {
      if(method === 'show') {
        show(methodOptions);
      } else {
        hide(methodOptions);
      }
    }
  });
});
}