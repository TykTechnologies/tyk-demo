import { SortBy } from './components/sorting.js';
import { Interactive, HandleApiSpecSelect, HandleTruncateText } from './components/interactive.js';
import { onProductFormSubmit, onAppFormSubmit, handleTLSCertificate } from './components/submit-form.js';
import { fromSearch, fromButton } from './components/set-element-value.js';
import { decoratePasswordReveal } from './components/decorate-password-reveal.js';
import { copyToClipboard } from './components/copy-to-clipboard.js';
import { ActivePageNumber } from './components/set-active-pagination-number.js';
import { CollapsibleSections } from './components/collapsible-sections.js';
import { RoleSelection } from './components/role-selection.js';;
import { SelectMultiple, SelectMultipleInput } from './components/multi-select.js';
import { SelectDocMenuItem } from './components/product-doc-menu.js';
import { ExportCSV, GetOverviewChartData, HandleCalendar, GetTrafficChartData, FilterObserver, OnChangeHandlerForFilters, OnChangeHandlerTrafficTimeUnit, OnChangeHandlerOverviewApps, GetErrorRateChartData, FilterObserverHanlderForTrafficChart, FilterObserverHanlderForErrorRateChart, OnChangeHandlerStatisticsErrorRate, GetLatencyChartData, FilterObserverHanlderForLatencyChart, OnChangeHandlerErrorRateTimeUnit, OnChangeHandlerLatencyTimeUnit} from './components/analytics.js';

var tooltipTriggerList = [].slice.call(
document.querySelectorAll('[data-bs-toggle="tooltip"]')
);
var tooltipList = tooltipTriggerList.map(function (tooltipTriggerEl) {
	return new bootstrap.Tooltip(tooltipTriggerEl);
});

/* Cards listing */
let defaultSortingElements = {
	mainWrapper: '.catalog-apis-container .card-container',
	elementWrapper: '.catalog-apis-container .card-container .card',
	elementTitle: '.catalog-apis-container .card-container .card .card-body .card-title',
	elementContent: '.catalog-apis-container .card-container .card .card-body',
	elementImage: '.catalog-apis-container .card-container .card img',
	elementCtaContainer: '.catalog-apis-container .card-container .card .card-cta',
	elementCTA: '.catalog-apis-container .card-container .card .card-cta .learn-more-cta',
}

let catalogueSorting = SortBy(defaultSortingElements);

/* Search - Catalogue & MyApps */
let defaultSearchElements = {
	elementsID: ['status', 'search', 'catalogue']
};
fromSearch(defaultSearchElements);

/* Cart form submission */
let elements = {
	formId: 'add-to-cart-form',
	productBtn: '.product-input-radio',
	catalogueBtn: '.catalogue-input-radio',
	addBtn: 'add-to-cart-btn'
}
let certElements = {
	fileInput: 'fileInput',
	uploadCertBtn: 'upload-cert',
	certName: 'certificate-name'
}
onProductFormSubmit(elements);
handleTLSCertificate(certElements);

/* Password decoration */
let allContentFields = document.querySelectorAll('.content-field');
allContentFields.forEach(decoratePasswordReveal);

let copyElems = document.querySelectorAll('.tykon-copy');
copyElems.forEach(copyToClipboard);

/* Interactive */
Interactive({
	cardSelector: '.profile-wrapper__card-section'
});

Interactive({
	cardSelector: '.apps-wrapper__card-section'
});

Interactive({
	cardSelector: '.apps-wrapper__card-section-certs'
});

Interactive({
	stepsSelector: '.step-wrapper',
	contentsSelector: '.content-wrapper',
	contentSelector: '.content-wrapper__content'
});
  
Interactive({
	stepsSelector: '.step-wrapper-api-docs',
	contentsSelector: '.content-wrapper-api-docs',
	contentSelector: '.content-wrapper__content-api-docs'
});

HandleApiSpecSelect({
	selectorId: "OasApiSelect",
	downloadSelectorId: "display-download-button",
	displaySelectorId: "oas-display-stoplight"
})
/* Interactive */
SelectMultiple({
	selector: '.analytics-select-many-apps',
	tagsWrapperSelector: '.select-tags-wrapper-apps',
	allValue: "All apps",
});
SelectMultipleInput("response-codes-traffic-chart");
SelectMultipleInput("response-codes-error-rate-chart");

HandleTruncateText(".product-api-details", ".api-description-text", "data-description");

/* Enable Bootstrap tooltips */
$(function() {
	$('[data-toggle="tooltip"]').tooltip()
})

ActivePageNumber({
	searchParam: 'page',
	paginationLink: '.pagination .page-item'
});

/* Collapsible cards using Bootstrap's collapse.
	 The module adds the ability to switch the arrow (if any)
*/
const collapsibleTogglers = document.querySelectorAll('.toggle-collapsible');
CollapsibleSections({
	triggerElements: collapsibleTogglers,
	collapsibleID: '#type-details'
});

/* Handle DCR content visibility withing portal_checkout.tmpl */
const dcrTriggers = document.querySelectorAll('.dcr-visibility');
dcrTriggers.forEach(t => {
	t.addEventListener('click', () => {
		const templateContent = document.querySelector('.dcr-templates');
		const shouldShow = t.value === 'create' ?? 'existing';
		templateContent?.classList?.replace(`${shouldShow ? 'd-none' : 'd-block'}`, `${shouldShow ? 'd-block' : 'd-none'}`);
	})
})
//sidebar active
let id = "/portal" + window.location.href.split("/portal")[1];
if (id.includes("users")) {
	id = id.split("/users")[0] + "/users"
}
let activeTab = document.getElementById(id);
activeTab?.classList.add('sidebar-active');

const roleOptions = document.querySelector('#selectRolesId');
RoleSelection(roleOptions);

let productDocMenu = document.getElementsByClassName('product-doc-side-menu');
SelectDocMenuItem(productDocMenu);

//analytics
GetOverviewChartData();
GetTrafficChartData({updateTab: true});
GetErrorRateChartData({updateTab: true});
GetLatencyChartData({updateTab: true});
OnChangeHandlerForFilters("traffic-time-unit", OnChangeHandlerTrafficTimeUnit);
OnChangeHandlerForFilters("error-rate-time-unit", OnChangeHandlerErrorRateTimeUnit);
OnChangeHandlerForFilters("analytics-overview-select-apps", OnChangeHandlerOverviewApps);
OnChangeHandlerForFilters("error-rate-statistics", OnChangeHandlerStatisticsErrorRate);
OnChangeHandlerForFilters("latency-time-unit", OnChangeHandlerLatencyTimeUnit);
ExportCSV({chartID: "traffic-chart", buttonID: "traffic-chart-csv", filename: "api-calls.csv"});
ExportCSV({chartID: "error-rate-chart", buttonID: "error-rate-chart-csv", filename: "error-rates.csv"});
ExportCSV({chartID: "hits-vs-errors-chart", buttonID: "hits-vs-errors-chart-csv", filename: "hits-vs-errors.csv"});
ExportCSV({chartID: "error-rates-chart", buttonID: "error-rates-chart-csv", filename: "error-rates-api.csv"});
ExportCSV({chartID: "error-breakdown-chart", buttonID: "error-breakdown-chart-csv", filename: "error-breakdown.csv"});
ExportCSV({chartID: "latency-chart", buttonID: "latency-chart-csv", filename: "latency.csv"});
HandleCalendar("#analytics-date-picker");
FilterObserver("apps-filter-traffic-chart", FilterObserverHanlderForTrafficChart);
FilterObserver("codes-filter-traffic-chart", FilterObserverHanlderForTrafficChart);
FilterObserver("apps-filter-error-rate-chart", FilterObserverHanlderForErrorRateChart);
FilterObserver("codes-filter-error-rate-chart", FilterObserverHanlderForErrorRateChart);
FilterObserver("apps-filter-latency-chart", FilterObserverHanlderForLatencyChart);
