export function SelectMultiple({selector, tagsWrapperSelector, allValue}) {
  let selectorList = document.querySelectorAll(selector);
  let allowedValues = [allValue];
  const init = () => {
    selectorList.forEach(element => {
      let tagsWrapper = element.previousElementSibling;
      while (tagsWrapper !== null) {
        if (tagsWrapper.matches(tagsWrapperSelector)) {
          var tagsWrapperChildren = tagsWrapper?.children;
          var defaultNode = tagsWrapperChildren?.item(0);
          break;
        }
        tagsWrapper = tagsWrapper.previousElementSibling;
      }
      element.addEventListener('change', (e) => {
        let value = e.target.value;
        if (allowedValues.length < 1 || value != allValue) {
          if (!allowedValues.includes(value) && !allowedValues.includes(allValue)) {
            element.value = '';
            let item = createChildItem(value);
            item.addEventListener('click', () => {
              tagsWrapper.removeChild(item);
              allowedValues = allowedValues.filter(item => item !== value);
              element.value = '';
            });
            tagsWrapper.appendChild(item);
            allowedValues.push(value);
          }
        }
      });
      defaultNode?.addEventListener('click', () => {
        tagsWrapper.removeChild(defaultNode);
        allowedValues = [];
        element.value = '';
      });
    });
  };
  init();
}

function createChildItem(value, isInput) {
  let item = document.createElement('div');
  item.classList.add('tag-item');
  if (isInput) {
    item.classList.add('mt-6');
  }
  item.innerHTML = `${value}
  <i class="bi bi-x x-icon"></i>`;
  return item
}

export function SelectMultipleInput(inputId) {
  let element = document.getElementById(inputId);
  let allowedValues = [];
  var tagsWrapper = element?.parentNode;
  element?.addEventListener("keydown", function(e) {
    if (e.key === "Enter") {
      e.preventDefault();
      let value = e.target.value;
      if (!allowedValues.includes(value)) {
        element.value = '';
        let item = createChildItem(value, true);
        item.addEventListener('click', () => {
          tagsWrapper.removeChild(item);
          allowedValues = allowedValues.filter(item => item !== value);
          element.value = '';
        });
        tagsWrapper.insertBefore(item, element);
        allowedValues.push(value);
      }
    }
  });
}