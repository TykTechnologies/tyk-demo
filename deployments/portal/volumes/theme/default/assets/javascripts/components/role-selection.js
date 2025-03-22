/* toggle role dropdown selection */
export function RoleSelection(roleOptions) {
    if (roleOptions != null){
        showSelectedRole(roleOptions);
        roleOptions.addEventListener('change', () => {
            showSelectedRole(roleOptions);
        })
    }
}

function showSelectedRole(roleOptions){
    for (let i=0; i < roleOptions.children.length; i++){
        document.querySelector("#"+roleOptions.children[i].value).hidden = true;
    }
    let selectedOption = roleOptions.children[roleOptions.selectedIndex]
    document.querySelector("#"+selectedOption.value).hidden = false;
}