export function onProductFormSubmit(elements) {
  const handleSubmit = () => {
    let cartForm = document.getElementById(elements.formId);

    if(!document.getElementById(elements.addBtn).dataset.singleCatalogue) {
      let productID = cartForm.querySelector(elements.catalogueBtn)?.dataset?.productId;
      cartForm.querySelector(elements.productBtn).value = productID;
    }

    cartForm.addEventListener('submit', (e) => {
      e.preventDefault();
      fetch(e.target.action, {
          method: 'POST',
          body: new URLSearchParams(new FormData(e.target))
      }).then((resp) => {
        if(resp.status === 200) {
          let successMsg = document.querySelector('.alert-success');
          successMsg.classList.replace('d-none', 'd-flex')
        }
      }).catch((error) => {
        console.error(error)
      }).finally(() => {
        /* Hide the modal */
        const modal = document.getElementById('addFromCatalogue');
        if(modal) {
          const modalBackdrops = document.getElementsByClassName('modal-backdrop');

          modal.classList.remove('show');
          modal.setAttribute('aria-hidden', 'true');
          modal.setAttribute('style', 'display: none');
          document.querySelector('body').classList.remove('modal-open');
          document.querySelector('body').style = '';
          document.querySelector('nav').style = '';
          if(modalBackdrops) {
            document.body.removeChild(modalBackdrops[0]);
          }
  
          /* Clear radio button state */
          let modalRadioButtons = modal.querySelectorAll('.catalogue-input-radio');
  
          modalRadioButtons.forEach(rb => {
            rb.checked = false;
          })
        }
      });
    });
  }

  const init = () => {
    document.addEventListener('DOMContentLoaded', () => { 
      document.getElementById(elements.addBtn)?.addEventListener('click', handleSubmit);
    });
  };

  init();
}

// Deprecated - if you want to still use this, you will need to add the following header:
// Content-Type: application/json
// 'X-CSRF-Token': document.querySelector('meta[name="csrf-token"]')?.getAttribute('content')
export function onAppFormSubmit(formId) {
  let appForm = document.getElementById(formId);
  const removeIrrelevantModes = (data) => {
    let submitData = [];
    let submitMode = document.activeElement.dataset.submitMode;

    for (let v of data.entries()) {
      if(v[0] === 'mode' && v[1] !== submitMode) {
        v = null;
      }
      if(v) {
        submitData.push(v);
      }
    }
    return submitData.reduce((acc,[k,v])=>(acc[k]=v,acc),{})
  }

  const handleFormSubmit = (e) => {
    e.preventDefault();
    const formData = removeIrrelevantModes(new FormData(appForm));
    fetch(e.target.action, {
        method: 'POST',
        body: JSON.stringify(formData),
        headers: {
          'Content-Type': 'application/json',
        }
      }).then((resp) => {
        window.location.reload(false);
      }).catch((error) => {
        alert(error)
        console.error(error)
      });
  }

  const init = () => {
    appForm?.addEventListener('submit', handleFormSubmit)
  };

  init();
}

export function handleTLSCertificate(certElements) {
  const fileInput = document.getElementById(certElements.fileInput);
  const uploadCertButton = document.getElementById(certElements.uploadCertBtn);
  const certificateName = document.getElementById(certElements.certName);

  fileInput?.addEventListener('change', handleFileSelect);

  function handleFileSelect(event) {
    const selectedFile = event.target.files[0];
    if (!selectedFile) {
      certificateName.textContent = 'No certificate selected';
      removeRemoveIcon();
      return;
    }
    const allowedExtensions = ['pem'];
    const fileExtension = selectedFile.name.split('.').pop().toLowerCase();
    if (!allowedExtensions.includes(fileExtension)) {
      fileInput.value = null;
      certificateName.textContent = 'No certificate selected';
      removeRemoveIcon();
      return;
    }
    certificateName.textContent = selectedFile.name;
    fileInput.value = selectedFile;
    addRemoveIcon();
  }

  function addRemoveIcon() {
    const parentDiv = certificateName.parentElement;
    const removeIcon = document.createElement('span');
    removeIcon.id = 'remove-icon';
    removeIcon.className = 'ml-2';
    removeIcon.innerHTML = '<img src="/assets/images/icons/remove.svg">';
    parentDiv.appendChild(removeIcon);
    removeIcon.addEventListener('click', handleRemoveIconClick);
  }

  function removeRemoveIcon() {
    const removeIcon = document.getElementById('remove-icon');
    if (removeIcon) {
      removeIcon.removeEventListener('click', handleRemoveIconClick);
      removeIcon.parentElement.removeChild(removeIcon);
    }
  }

  function handleRemoveIconClick() {
    fileInput.value = null;
    certificateName.textContent = 'No certificate selected';
    removeRemoveIcon();
  }

  uploadCertButton?.addEventListener('click', () => {
    fileInput.click();
  });
}