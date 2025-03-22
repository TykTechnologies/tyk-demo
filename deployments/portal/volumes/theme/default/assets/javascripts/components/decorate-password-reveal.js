/*
  Clicking on the eye icon it should show the password that has been entered.
  Clicking on the  icon again, it should revert back to the initial state.

  In order to work for non Inputs of type password you'll need a wrapper element with position set to relative &
  the content to have a class of d-block
*/

export function decoratePasswordReveal(content) {
  let isRevealed = false;
  const viewIconSrc = '/assets/images/icons/view-password.svg';
  const hideIconSrc = '/assets/images/icons/hide-password.svg';

  const img = document.createElement('img');
  img.classList.add('password-icon');
  img.src = isRevealed ? viewIconSrc : hideIconSrc ;
  img.addEventListener('click', (e) => {
    isRevealed = !isRevealed;
    e.target.src = isRevealed ? viewIconSrc : hideIconSrc ;
    if(content.nodeName === 'INPUT') {
      content.type = isRevealed ? 'text' : 'password';
    } else {
      isRevealed ? content.classList.replace('d-block', 'd-none') : content.classList.replace('d-none', 'd-block')
    }
  });

  content.insertAdjacentElement('afterend', img);
}

