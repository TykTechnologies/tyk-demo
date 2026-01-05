import { SortBy } from "./components/sorting.js";
import {
  Interactive,
  HandleApiSpecSelect,
  HandleTruncateText,
} from "./components/interactive.js";
import {
  onProductFormSubmit,
  onAppFormSubmit,
  handleTLSCertificate,
} from "./components/submit-form.js";
import { fromSearch, fromButton } from "./components/set-element-value.js";
import { decoratePasswordReveal } from "./components/decorate-password-reveal.js";
import { copyToClipboard } from "./components/copy-to-clipboard.js";
import { ActivePageNumber } from "./components/set-active-pagination-number.js";
import { CollapsibleSections } from "./components/collapsible-sections.js";
import {
  RoleSelection,
  ShowRoleDetails,
  InitRoleSelectionHandler,
} from "./components/role-selection.js";
import {
  SelectMultiple,
  SelectMultipleInput,
} from "./components/multi-select.js";
import { SelectDocMenuItem } from "./components/product-doc-menu.js";
import {
  ExportCSV,
  GetOverviewChartData,
  HandleCalendar,
  GetTrafficChartData,
  FilterObserver,
  OnChangeHandlerForFilters,
  OnChangeHandlerTrafficTimeUnit,
  OnChangeHandlerOverviewApps,
  GetErrorRateChartData,
  FilterObserverHanlderForTrafficChart,
  FilterObserverHanlderForErrorRateChart,
  OnChangeHandlerStatisticsErrorRate,
  GetLatencyChartData,
  FilterObserverHanlderForLatencyChart,
  OnChangeHandlerErrorRateTimeUnit,
  OnChangeHandlerLatencyTimeUnit,
} from "./components/analytics.js";

var tooltipTriggerList = [].slice.call(
  document.querySelectorAll('[data-bs-toggle="tooltip"]')
);
var tooltipList = tooltipTriggerList.map(function (tooltipTriggerEl) {
  return new bootstrap.Tooltip(tooltipTriggerEl);
});

/* Cards listing */
let defaultSortingElements = {
  mainWrapper: ".catalog-apis-container .card-container",
  elementWrapper: ".catalog-apis-container .card-container .card",
  elementTitle:
    ".catalog-apis-container .card-container .card .card-body .card-title",
  elementContent: ".catalog-apis-container .card-container .card .card-body",
  elementImage: ".catalog-apis-container .card-container .card img",
  elementCtaContainer:
    ".catalog-apis-container .card-container .card .card-cta",
  elementCTA:
    ".catalog-apis-container .card-container .card .card-cta .learn-more-cta",
};

let catalogueSorting = SortBy(defaultSortingElements);

/* Search - Catalogue & MyApps */
let defaultSearchElements = {
  elementsID: ["status", "search", "catalogue"],
};
fromSearch(defaultSearchElements);

/* Cart form submission */
let elements = {
  formId: "add-to-cart-form",
  productBtn: ".product-input-radio",
  catalogueBtn: ".catalogue-input-radio",
  addBtn: "add-to-cart-btn",
};
let certElements = {
  fileInput: "fileInput",
  uploadCertBtn: "upload-cert",
  certName: "certificate-name",
};
onProductFormSubmit(elements);
handleTLSCertificate(certElements);

/* Password decoration */
let allContentFields = document.querySelectorAll(".content-field");
allContentFields.forEach(decoratePasswordReveal);

let copyElems = document.querySelectorAll(".tykon-copy");
copyElems.forEach(copyToClipboard);

/* Interactive */
Interactive({
  cardSelector: ".profile-wrapper__card-section",
});

Interactive({
  cardSelector: ".apps-wrapper__card-section",
});

Interactive({
  cardSelector: ".apps-wrapper__card-section-certs",
});

Interactive({
  stepsSelector: ".step-wrapper",
  contentsSelector: ".content-wrapper",
  contentSelector: ".content-wrapper__content",
});

Interactive({
  stepsSelector: ".step-wrapper-api-docs",
  contentsSelector: ".content-wrapper-api-docs",
  contentSelector: ".content-wrapper__content-api-docs",
});

HandleApiSpecSelect({
  selectorId: "OasApiSelect",
  downloadSelectorId: "display-download-button",
  displaySelectorId: "oas-display-stoplight",
});
/* Interactive */
SelectMultiple({
  selector: ".analytics-select-many-apps",
  tagsWrapperSelector: ".select-tags-wrapper-apps",
  allValue: "All apps",
});
SelectMultipleInput("response-codes-traffic-chart");
SelectMultipleInput("response-codes-error-rate-chart");

HandleTruncateText(
  ".product-api-details",
  ".api-description-text",
  "data-description"
);

/* Enable Bootstrap tooltips */
$(function () {
  $('[data-toggle="tooltip"]').tooltip();
});

ActivePageNumber({
  searchParam: "page",
  paginationLink: ".pagination .page-item",
});

/* Collapsible cards using Bootstrap's collapse.
	 The module adds the ability to switch the arrow (if any)
*/
const collapsibleTogglers = document.querySelectorAll(".toggle-collapsible");
CollapsibleSections({
  triggerElements: collapsibleTogglers,
  collapsibleID: "#type-details",
});

/* Handle DCR content visibility withing portal_checkout.tmpl */
const dcrTriggers = document.querySelectorAll(".dcr-visibility");
dcrTriggers.forEach((t) => {
  t.addEventListener("click", () => {
    const templateContent = document.querySelector(".dcr-templates");
    const shouldShow = t.value === "create" ?? "existing";
    templateContent?.classList?.replace(
      `${shouldShow ? "d-none" : "d-block"}`,
      `${shouldShow ? "d-block" : "d-none"}`
    );
  });
});

/* Handle credential selection visibility in portal_checkout.tmpl
 * HTML is server-rendered, JS only handles show/hide interactivity
 */

/* Toggle between create_new and reuse_existing credential options */
document.addEventListener('change', (e) => {
  if (e.target.name !== 'credential_action') return;

  const container = e.target.closest('.app-credentials');
  if (!container) return;

  const selectDiv = container.querySelector('[id^="credential-select-"]');
  const infoDiv = container.querySelector('[id^="new-credential-info-"]');
  const dropdownBtn = container.querySelector('.credential-dropdown .dropdown-toggle');
  const hiddenInput = container.querySelector('input[name="credential_id"]');

  const isReuse = e.target.value === 'reuse_existing';

  if (selectDiv) {
    selectDiv.classList.toggle('d-none', !isReuse);
    selectDiv.classList.toggle('d-block', isReuse);
  }
  if (infoDiv) {
    infoDiv.classList.toggle('d-none', isReuse);
    infoDiv.classList.toggle('d-block', !isReuse);
  }
  if (dropdownBtn) {
    dropdownBtn.disabled = !isReuse;
    if (!isReuse) {
      // Reset dropdown to placeholder
      dropdownBtn.innerHTML = '<span class="placeholder-text">Select a credential</span>';
      if (hiddenInput) hiddenInput.value = '';
    }
  }
});

/* Handle credential dropdown item selection */
document.addEventListener('click', (e) => {
  const dropdownItem = e.target.closest('.credential-dropdown .dropdown-item');
  if (!dropdownItem) return;

  e.preventDefault();

  const dropdown = dropdownItem.closest('.credential-dropdown');
  const dropdownBtn = dropdown.querySelector('.dropdown-toggle');
  const hiddenInput = dropdown.querySelector('input[name="credential_id"]');

  const credId = dropdownItem.dataset.value;
  const displayName = dropdownItem.dataset.displayName;
  const plan = dropdownItem.dataset.plan;
  const authType = dropdownItem.dataset.auth;

  // Update hidden input
  if (hiddenInput) hiddenInput.value = credId;

  // Update button content to show selected credential
  dropdownBtn.innerHTML = `
    <span class="selected-content">
      <span class="credential-label">${displayName} | ${plan}</span>
      <span class="pill">${authType}</span>
    </span>
  `;

  // Mark item as active
  dropdown.querySelectorAll('.dropdown-item').forEach(item => item.classList.remove('active'));
  dropdownItem.classList.add('active');
});

/* Handle app-action radio button changes (create new app vs existing app) */
const appActionRadios = document.querySelectorAll('input[name="app-action"]');
appActionRadios.forEach((radio) => {
  radio.addEventListener("change", (e) => {
    const form = e.target.closest("form");
    if (!form) return;

    const credentialSection = form.querySelector(".credential-selection-section");
    if (!credentialSection) return;

    const newAppCredentials = credentialSection.querySelector(".new-app-credentials");
    const allAppCredentials = credentialSection.querySelectorAll(".app-credentials");

    if (e.target.value === "create") {
      // Show new app credentials section
      if (newAppCredentials) newAppCredentials.style.display = "block";
      allAppCredentials.forEach((div) => {
        div.style.display = "none";
        // Disable credential dropdown when creating new app
        const dropdownBtn = div.querySelector('.credential-dropdown .dropdown-toggle');
        if (dropdownBtn) {
          dropdownBtn.disabled = true;
        }
      });
    } else if (e.target.value === "existing") {
      // Hide new app credentials section
      if (newAppCredentials) newAppCredentials.style.display = "none";

      // Show credentials for the selected app
      const appSelect = form.querySelector("#appsControlSelect");
      if (appSelect && appSelect.value) {
        showCredentialsForApp(appSelect, appSelect.value);
      }
    }
  });
});

/* Handle app selection changes to show correct credentials */
const appSelects = document.querySelectorAll("#appsControlSelect");
appSelects.forEach((appSelect) => {
  // Listen for app selection changes
  appSelect.addEventListener("change", (e) => {
    const selectedAppId = e.target.value;
    showCredentialsForApp(e.target, selectedAppId);
  });

  // Initialize: disable all credential dropdowns and hidden inputs except for currently selected app
  const form = appSelect.closest("form");
  if (form) {
    const credentialSection = form.querySelector(".credential-selection-section");
    if (credentialSection) {
      const allAppCredentials = credentialSection.querySelectorAll(".app-credentials");
      allAppCredentials.forEach((div) => {
        const dropdownBtn = div.querySelector('.credential-dropdown .dropdown-toggle');
        if (dropdownBtn) {
          dropdownBtn.disabled = true;
        }
        // Disable hidden inputs so they don't get submitted with the form
        const hiddenInput = div.querySelector('input[name="credential_id"]');
        if (hiddenInput) {
          hiddenInput.disabled = true;
        }
      });

      // If an app is already selected, enable its credential dropdown and hidden input
      if (appSelect.value) {
        const selectedAppCredentials = credentialSection.querySelector(`.app-credentials[data-app-id="${appSelect.value}"]`);
        if (selectedAppCredentials) {
          const dropdownBtn = selectedAppCredentials.querySelector('.credential-dropdown .dropdown-toggle');
          if (dropdownBtn) {
            dropdownBtn.disabled = false;
          }
          // Enable the hidden input for the selected app
          const hiddenInput = selectedAppCredentials.querySelector('input[name="credential_id"]');
          if (hiddenInput) {
            hiddenInput.disabled = false;
          }
        }
      }
    }
  }
});

/* Show credentials section for selected app (HTML is server-rendered) */
function showCredentialsForApp(appSelectElement, appId) {
  const form = appSelectElement.closest("form");
  if (!form) return;

  const credentialSection = form.querySelector(".credential-selection-section");
  if (!credentialSection) return;

  // Hide all app-credentials divs, disable their dropdowns and hidden inputs
  credentialSection.querySelectorAll(".app-credentials").forEach((div) => {
    div.style.display = "none";
    const dropdownBtn = div.querySelector('.credential-dropdown .dropdown-toggle');
    if (dropdownBtn) dropdownBtn.disabled = true;
    // Disable hidden inputs so they don't get submitted with the form
    const hiddenInput = div.querySelector('input[name="credential_id"]');
    if (hiddenInput) hiddenInput.disabled = true;
  });

  // Show the credentials div for the selected app
  const selectedAppCredentials = credentialSection.querySelector(`.app-credentials[data-app-id="${appId}"]`);
  if (!selectedAppCredentials) return;

  selectedAppCredentials.style.display = "block";

  // Enable the hidden input for the selected app so it gets submitted
  const selectedHiddenInput = selectedAppCredentials.querySelector('input[name="credential_id"]');
  if (selectedHiddenInput) selectedHiddenInput.disabled = false;

  // Enable dropdown only if "reuse_existing" is selected
  const dropdownBtn = selectedAppCredentials.querySelector('.credential-dropdown .dropdown-toggle');
  const reuseRadio = selectedAppCredentials.querySelector('input[name="credential_action"][value="reuse_existing"]');
  if (dropdownBtn && reuseRadio && reuseRadio.checked) {
    dropdownBtn.disabled = false;
  }
}

//sidebar active
let id = "/portal" + window.location.href.split("/portal")[1];
if (id.includes("users")) {
  id = id.split("/users")[0] + "/users";
}
let activeTab = document.getElementById(id);
activeTab?.classList.add("sidebar-active");

const roleOptions = document.querySelector("#selectRolesId");
RoleSelection(roleOptions);

InitRoleSelectionHandler();

let productDocMenu = document.getElementsByClassName("product-doc-side-menu");
SelectDocMenuItem(productDocMenu);

//analytics
GetOverviewChartData();
GetTrafficChartData({ updateTab: true });
GetErrorRateChartData({ updateTab: true });
GetLatencyChartData({ updateTab: true });
OnChangeHandlerForFilters("traffic-time-unit", OnChangeHandlerTrafficTimeUnit);
OnChangeHandlerForFilters(
  "error-rate-time-unit",
  OnChangeHandlerErrorRateTimeUnit
);
OnChangeHandlerForFilters(
  "analytics-overview-select-apps",
  OnChangeHandlerOverviewApps
);
OnChangeHandlerForFilters(
  "error-rate-statistics",
  OnChangeHandlerStatisticsErrorRate
);
OnChangeHandlerForFilters("latency-time-unit", OnChangeHandlerLatencyTimeUnit);
ExportCSV({
  chartID: "traffic-chart",
  buttonID: "traffic-chart-csv",
  filename: "api-calls.csv",
});
ExportCSV({
  chartID: "error-rate-chart",
  buttonID: "error-rate-chart-csv",
  filename: "error-rates.csv",
});
ExportCSV({
  chartID: "hits-vs-errors-chart",
  buttonID: "hits-vs-errors-chart-csv",
  filename: "hits-vs-errors.csv",
});
ExportCSV({
  chartID: "error-rates-chart",
  buttonID: "error-rates-chart-csv",
  filename: "error-rates-api.csv",
});
ExportCSV({
  chartID: "error-breakdown-chart",
  buttonID: "error-breakdown-chart-csv",
  filename: "error-breakdown.csv",
});
ExportCSV({
  chartID: "latency-chart",
  buttonID: "latency-chart-csv",
  filename: "latency.csv",
});
HandleCalendar("#analytics-date-picker");
FilterObserver(
  "apps-filter-traffic-chart",
  FilterObserverHanlderForTrafficChart
);
FilterObserver(
  "codes-filter-traffic-chart",
  FilterObserverHanlderForTrafficChart
);
FilterObserver(
  "apps-filter-error-rate-chart",
  FilterObserverHanlderForErrorRateChart
);
FilterObserver(
  "codes-filter-error-rate-chart",
  FilterObserverHanlderForErrorRateChart
);
FilterObserver(
  "apps-filter-latency-chart",
  FilterObserverHanlderForLatencyChart
);

$(document).on('show.bs.modal', '[id^="change-plan-"]', function () {
  const modal = $(this);
  const plansGrid = modal.find('.plans-grid');
  const hiddenInput = modal.find('input[type="hidden"][name="new_plan_id"]');
  const submitBtn = modal.find('button[type="submit"]');

  plansGrid.find('.plan-card').on('click', function() {
    if ($(this).hasClass('disabled') || $(this).data('is-current')) {
      return;
    }

    const planId = $(this).data('plan-id');
    plansGrid.find('.plan-card').removeClass('selected');
    $(this).addClass('selected');
    hiddenInput.val(planId);
    submitBtn.prop('disabled', false);
  });
});

$(document).on('hidden.bs.modal', '[id^="change-plan-"]', function () {
  const modal = $(this);
  const plansGrid = modal.find('.plans-grid');
  const hiddenInput = modal.find('input[type="hidden"][name="new_plan_id"]');
  const submitBtn = modal.find('button[type="submit"]');

  plansGrid.find('.plan-card').removeClass('selected');
  hiddenInput.val('');
  submitBtn.prop('disabled', true);
});
