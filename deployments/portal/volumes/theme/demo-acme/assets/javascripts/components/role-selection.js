/* toggle role dropdown selection */
export function RoleSelection(roleOptions) {
  if (roleOptions != null) {
    showSelectedRole(roleOptions);
    roleOptions.addEventListener("change", () => {
      showSelectedRole(roleOptions);
    });
  }
}

function showSelectedRole(roleOptions) {
  for (let i = 0; i < roleOptions.children.length; i++) {
    document.querySelector("#" + roleOptions.children[i].value).hidden = true;
  }
  let selectedOption = roleOptions.children[roleOptions.selectedIndex];
  document.querySelector("#" + selectedOption.value).hidden = false;
}

export function OnChangeHandlerForShowRoleDetails(filterID, handler) {
  document.getElementById(filterID)?.addEventListener("change", (e) => {
    handler(e);
  });
}

export function InitRoleSelectionHandler() {
  document.querySelectorAll('input[name="role"]').forEach((radio) => {
    radio.addEventListener("change", (e) => {
      ShowRoleDetails(e.target.id);
    });
  });
}

export function ShowRoleDetails(id) {
  const container = document.querySelector(".dashed-table-border");
  if (!container) return;

  container.querySelectorAll('[id^="consumer-users"]').forEach((el) => {
    el.hidden = true;
  });

  const target = container.querySelector(`#consumer-users`);
  if (target) target.hidden = false;
}
