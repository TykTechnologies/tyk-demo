/*
  fromSearch()
    Assign the parameter values to elements if the query param matches the ID of the element.

  frombutton()
    Pass data from an element (via data attribute) to an other element's value. 
  
*/

export function fromSearch(defaults) {
  const params = new URLSearchParams(window.location.search);

  if (!params.keys().next().done) {
    defaults.elementsID.forEach(id => {
      let selectElement = document.getElementById(id);
      if (selectElement) selectElement.value = params.get(id);
    })
  }
};

export function fromButton(defaults) {
  let getValueFrom = document.querySelectorAll(`[data-${defaults.data_attribute}]`);
  let setValueTo = document.getElementById(defaults.to);

  getValueFrom.forEach(el => {
    el.addEventListener('click', function() {
      setValueTo.value = el.getAttribute(`data-${defaults.data_attribute}`);
    });
  });
};

