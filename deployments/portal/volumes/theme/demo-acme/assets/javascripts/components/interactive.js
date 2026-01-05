function InfoCard({ element, onChange, index }) {
  let $editBtn = element.querySelector('[data-action="edit"]');
  let $cancelBtn = element.querySelector('[data-action="cancel"]');
  let $editModeBtns = element.querySelector(".disable-editing");
  let $editEnableBtns = element.querySelector(".enable-editing");
  let $staticDataWrapper = element.querySelector(".card-footer__static-data");
  let $dynamicDataWrapper = element.querySelector(".card-footer__dynamic-data");

  const showEditMode = () => {
    $editBtn?.classList.replace("d-block", "d-none");
    $editEnableBtns?.classList.replace("d-block", "d-none");
    $editModeBtns?.classList.replace("d-none", "d-block");
    $staticDataWrapper?.classList.replace("d-block", "d-none");
    $dynamicDataWrapper?.classList.replace("d-none", "d-block");
    onChange({ index, state: true });
  };

  const hideEditMode = () => {
    $editModeBtns?.classList.replace("d-block", "d-none");
    $editBtn?.classList.replace("d-none", "d-block");
    $editEnableBtns?.classList.replace("d-none", "d-block");
    $staticDataWrapper?.classList.replace("d-none", "d-block");
    $dynamicDataWrapper?.classList.replace("d-block", "d-none");
    onChange({ index, state: false });
  };

  const bindEvents = () => {
    $editBtn?.addEventListener("click", showEditMode);
    $cancelBtn?.addEventListener("click", hideEditMode);
  };

  bindEvents();

  return {
    showEditMode,
    hideEditMode,
  };
}

function Toggle({
  element,
  onChange,
  index,
  contentWrapper,
  stepsSelector,
  contentSelector,
}) {
  let stepsCollection = element.querySelectorAll(`${stepsSelector} .step`);
  let contentCollection =
    contentWrapper[index].querySelectorAll(contentSelector);

  function handleContent(i, stepsCollection, contentCollection) {
    onChange({ stepIndex: i, stepsCollection, contentCollection });
  }

  const bindEvents = () => {
    stepsCollection.forEach((s, i) => {
      s.addEventListener(
        "click",
        handleContent.bind(null, i, stepsCollection, contentCollection),
        false,
      );
    });
  };

  const init = () => {
    bindEvents();
  };

  init();
}

export function Interactive({
  cardSelector,
  stepsSelector,
  contentsSelector,
  contentSelector,
}) {
  let infoCardsCollection = document.querySelectorAll(cardSelector);
  let stepsWrapper = document.querySelectorAll(stepsSelector);
  let contentWrapper = document.querySelectorAll(contentsSelector);

  const onCardToggles = ({ index }) => {
    if (stepsWrapper) {
      stepsWrapper.forEach((instance, i) => {
        if (index !== i) {
          instance.hideEditMode();
        }
      });
    }
  };

  const toggleSections = ({
    stepIndex,
    stepsCollection,
    contentCollection,
  }) => {
    contentCollection?.forEach((c) => {
      c.classList.replace("d-block", "d-none");
      contentCollection[stepIndex].classList.replace("d-none", "d-block");
    });

    stepsCollection?.forEach((s) => {
      s.classList.remove("active");
      stepsCollection[stepIndex].classList.add("active");
      let footer = document.querySelector("footer");
      let activeTab = stepsCollection[stepIndex];
      let redoc = document.getElementById("redoc-wrapper");
      if (activeTab && activeTab.innerHTML != "API SPECIFICATIONS") {
        footer.style.marginTop = "0px";
      } else if (
        activeTab &&
        activeTab.innerHTML == "API SPECIFICATIONS" &&
        redoc
      ) {
        footer.style.marginTop = redoc.clientHeight + "px";
      }
    });
  };

  const init = () => {
    infoCardsCollection.forEach((el, index) =>
      InfoCard({ element: el, onChange: onCardToggles, index }),
    );
    stepsWrapper.forEach((el, index) =>
      Toggle({
        element: el,
        onChange: toggleSections,
        index,
        contentWrapper,
        stepsSelector,
        contentSelector,
      }),
    );
  };

  init();
}
function isOAS(value) {
  return /^.*\.(json|yaml|yml)$/i.test(value);
}

function isRedoc(value) {
  return value === "product_doc_redoc";
}

function isStoplight(value) {
  return value === "product_doc_stoplight_spec";
}

function isGraphql(value){
  return value === "product_doc_graphql_playground";
}

function isAsyncApi(value) {
  return value === "product_doc_asyncapi";
}

function handleContent(element, content) {
  while (element.firstChild) {
    element.removeChild(element.firstChild);
  }
  element.appendChild(content);
}

function getURLValue(urlArr) {
  if (urlArr.length > 1) {
    return urlArr.join("-");
  }
  return urlArr[0];
}

export function HandleApiSpecSelect({
  selectorId,
  downloadSelectorId,
  displaySelectorId,
}) {
  let selector = document.getElementById(selectorId);
  let downloadSelector = document.getElementById(downloadSelectorId);
  let displaySelector = document.getElementById(displaySelectorId);
  let oasTemplate =
    selector?.options[selector.selectedIndex]?.getAttribute("data-template");
  let path = downloadSelector?.getAttribute("data-path");
  let [apiID, ...docURL] =
    selector && selector.value ? selector.value.split("-") : [];
  let tmplIsRedoc = isRedoc(oasTemplate);
  let tmplIsAsyncApi = isAsyncApi(oasTemplate);
  let tmplIsStoplight = isStoplight(oasTemplate);
  let tmplIsGraphql = isGraphql(oasTemplate);


  let url = getURLValue(docURL);

  if (tmplIsGraphql){
    let serverEndpoint = selector?.options[selector.selectedIndex]?.getAttribute("data-graphqlendpoint")
    initGraphQL(apiID, serverEndpoint);
  }else if (selector && isOAS(url)) {
    if (tmplIsRedoc) {
      initRedoc(url);
    } else if (tmplIsAsyncApi) {
      initAsyncApi(url);
    } else if (tmplIsStoplight) {
      initStoplight(url);
    }
  }

  selector?.addEventListener("change", (e) => {
    let oasTemplate =
      selector?.options[selector.selectedIndex]?.getAttribute("data-template");
    let tmplIsRedoc = isRedoc(oasTemplate);
    let tmplIsAsyncApi = isAsyncApi(oasTemplate);
    let tmplIsStoplight = isStoplight(oasTemplate);
    let tmplIsGraphql = isGraphql(oasTemplate);

    let [apiID, ...docURL] = e.target.value.split("-");
    let url = getURLValue(docURL);
    downloadSelector.action = `${path}/${apiID}/docs/download`;
    if (tmplIsGraphql){
      let serverEndpoint = selector?.options[selector.selectedIndex]?.getAttribute("data-graphqlendpoint")
      initGraphQL(apiID, serverEndpoint);
    } else {
      if (tmplIsRedoc) {
        initRedoc(url);
      } else if (tmplIsAsyncApi) {
        initAsyncApi(url);
      } else if (tmplIsStoplight) {
        initStoplight(url);
      }
    }
  });
}

function hideAllElements(apiDocWrapper) {
  if (apiDocWrapper) {
    Array.from(apiDocWrapper.children).forEach((child) => {
      child.style.display = "none";
    });
  }
}

function getOrCreateWrapper(apiDocWrapper, wrapperId) {
  let existingWrapper = document.getElementById(wrapperId);
  let wrapper;

  if (!existingWrapper) {
    wrapper = document.createElement("div");
    wrapper.id = wrapperId;
    apiDocWrapper.appendChild(wrapper);
  } else {
    wrapper = existingWrapper;
    wrapper.style.display = "block";
  }

  return wrapper;
}

function initGraphQL(apiID, _endpointUrl) {
  let apiDocWrapper = document.getElementById("api_doc_wrapper");

  hideAllElements(apiDocWrapper);

  let wrapper = getOrCreateWrapper(apiDocWrapper, "graphql-playground-wrapper");

  // Reuse the same base path used for downloads to build the iframe src
  let downloadSelector = document.getElementById("display-download-button");
  let path = downloadSelector?.getAttribute("data-path") || "";

  let iframe = document.createElement("iframe");
  iframe.setAttribute("src", `${path}/${apiID}/docs?embed=1`);
  iframe.setAttribute("width", "100%");
  iframe.setAttribute("height", "600");
  iframe.setAttribute("frameborder", "0");

  handleContent(wrapper, iframe);
}

function initRedoc(url) {
  let apiDocWrapper = document.getElementById("api_doc_wrapper");

  hideAllElements(apiDocWrapper);

  let wrapper = getOrCreateWrapper(apiDocWrapper, "redoc-wrapper");

  if (Redoc) {
    Redoc.init(
      url,
      {
        scrollYOffset: ".navbar",
      },
      wrapper,
      (redoc) => {
        let footer = document.querySelector("footer");
        let activeTab = document.querySelector(".step.active.tab");
        if (activeTab?.innerHTML == "API SPECIFICATIONS") {
          footer.style.marginTop = wrapper.clientHeight + "px";
        }
      },
    );
  }
}

function initAsyncApi(url) {
  let apiDocWrapper = document.getElementById("api_doc_wrapper");

  hideAllElements(apiDocWrapper);

  let wrapper = getOrCreateWrapper(apiDocWrapper, "asyncapi");

  if (AsyncApiStandalone) {
    AsyncApiStandalone.render(
      {
        schema: {
          url: url,
          options: { method: "GET", mode: "cors" },
        },
        config: {
          show: {
            sidebar: false,
            info: true,
            operations: true,
            servers: true,
            messages: true,
            schemas: true,
            errors: true,
          },
          expand: {
            messageExamples: false,
          },
          sidebar: {
            showServers: "byDefault",
            showOperations: "byDefault",
          },
        },
      },
      wrapper,
    );
  }
}

function initStoplight(url) {
  console.log("initializing spotlight")
  let apiDocWrapper = document.getElementById("api_doc_wrapper");

  hideAllElements(apiDocWrapper);

  let wrapper = getOrCreateWrapper(apiDocWrapper, "oas-display-stoplight");

  let elementsApi = document.createElement("elements-api");
  elementsApi.setAttribute("apiDescriptionUrl", url);
  elementsApi.setAttribute("router", "hash");
  elementsApi.setAttribute("layout", "responsive");
  elementsApi.setAttribute("hideExport", "true");
  handleContent(wrapper, elementsApi);
}

export function HandleTruncateText(selectorWrapper, selector, attribute) {
  let elementWrapper = document.querySelectorAll(selectorWrapper);
  elementWrapper?.forEach((element) => {
    let textElement = element.querySelector(selector);
    let maxHeight = element.style.maxHeight;
    if (
      textElement &&
      textElement.getAttribute(attribute) != textElement.innerText
    ) {
      element.addEventListener("mouseover", function () {
        handleTextExpand(textElement, attribute);
        element.style.maxHeight = "none";
      });

      element.addEventListener("mouseout", function () {
        handleTextExpand(textElement, attribute);
        element.style.maxHeight = maxHeight;
      });
    }
  });
}

function handleTextExpand(textElement, attribute) {
  let data = textElement?.getAttribute(attribute);
  textElement.setAttribute(attribute, textElement.innerText);
  textElement.innerText = data;
}
