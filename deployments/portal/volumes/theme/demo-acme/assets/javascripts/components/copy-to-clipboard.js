export function copyToClipboard(element) {
  element.addEventListener('click', e => {
    let valueToCopy = element.dataset.copyValue;
    let successMsg = document.getElementById('success-msg');
    
    navigator.clipboard.writeText(valueToCopy);
    successMsg?.classList?.replace('d-none', 'd-block');
    setTimeout(() => {
      successMsg?.classList?.replace('d-block', 'd-none');
    }, 2000);
  });
}