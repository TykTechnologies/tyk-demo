import { u as useToast, r as reactExports, i as isOAuthPopup, j as jsxRuntimeExports, p as parseOAuthCallbackParams, S as SESSION_KEYS, c as createProxyFetch, a as initializeInspectorConfig, b as isHttpUrl, d as parseResourceMetadataUrlParam, s as saveScopeToSessionStorage, I as InspectorOAuthClientProvider, e as auth, g as generateOAuthErrorDescription, f as getServerSpecificKey, O as OAuthTokensSchema, h as postOAuthResultToOpener, k as OAUTH_POPUP_MESSAGE } from "./index-BUgq-xuC.js";
const OAuthCallback = ({ onConnect }) => {
  const { toast } = useToast();
  const hasProcessedRef = reactExports.useRef(false);
  reactExports.useEffect(() => {
    const inPopup = isOAuthPopup();
    const fail = (description) => {
      if (inPopup) {
        postOAuthResultToOpener({
          type: OAUTH_POPUP_MESSAGE,
          ok: false,
          error: description
        });
        return;
      }
      void toast({
        title: "OAuth Authorization Error",
        description,
        variant: "destructive"
      });
    };
    const handleCallback = async () => {
      if (hasProcessedRef.current) return;
      hasProcessedRef.current = true;
      const params = parseOAuthCallbackParams(window.location.search);
      const search = new URLSearchParams(window.location.search);
      const isStart = search.get("flow") === "start";
      const flowServerUrl = (isStart ? search.get("serverUrl") : null) || sessionStorage.getItem(SESSION_KEYS.SERVER_URL);
      const CONNECTION_TYPE_KEY = getServerSpecificKey(
        "mcp_popup_connection_type",
        flowServerUrl ?? void 0
      );
      const RESOURCE_METADATA_URL_KEY = getServerSpecificKey(
        "mcp_popup_resource_metadata_url",
        flowServerUrl ?? void 0
      );
      if (isStart) {
        try {
          sessionStorage.setItem(
            CONNECTION_TYPE_KEY,
            search.get("connectionType") || "proxy"
          );
          const rmu = search.get("resourceMetadataUrl");
          if (rmu) sessionStorage.setItem(RESOURCE_METADATA_URL_KEY, rmu);
          else sessionStorage.removeItem(RESOURCE_METADATA_URL_KEY);
        } catch {
        }
      }
      const connectionType = search.get("connectionType") || sessionStorage.getItem(CONNECTION_TYPE_KEY) || "proxy";
      const fetchFn = connectionType === "proxy" ? createProxyFetch(initializeInspectorConfig("inspectorConfig_v1")) : void 0;
      if (isStart && !params.successful) {
        const serverUrl2 = search.get("serverUrl");
        if (!serverUrl2) return fail("Missing Server URL");
        if (!isHttpUrl(serverUrl2)) return fail("Invalid Server URL");
        const scope = search.get("scope") || void 0;
        const resourceMetadataUrl2 = parseResourceMetadataUrlParam(
          search.get("resourceMetadataUrl")
        );
        try {
          saveScopeToSessionStorage(serverUrl2, scope);
          const provider = new InspectorOAuthClientProvider(serverUrl2);
          await auth(provider, {
            serverUrl: serverUrl2,
            scope,
            resourceMetadataUrl: resourceMetadataUrl2,
            fetchFn
          });
        } catch (error) {
          return fail(`Unexpected error occurred: ${error}`);
        }
        return;
      }
      if (!params.successful) {
        return fail(generateOAuthErrorDescription(params));
      }
      const serverUrl = sessionStorage.getItem(SESSION_KEYS.SERVER_URL);
      if (!serverUrl) return fail("Missing Server URL");
      const resourceMetadataUrl = parseResourceMetadataUrlParam(
        sessionStorage.getItem(RESOURCE_METADATA_URL_KEY)
      );
      let result;
      try {
        const provider = new InspectorOAuthClientProvider(serverUrl);
        result = await auth(provider, {
          serverUrl,
          authorizationCode: params.code,
          resourceMetadataUrl,
          fetchFn
        });
      } catch (error) {
        return fail(`Unexpected error occurred: ${error}`);
      }
      if (result !== "AUTHORIZED") {
        return fail(
          `Expected to be authorized after providing auth code, got: ${result}`
        );
      }
      const raw = sessionStorage.getItem(
        getServerSpecificKey(SESSION_KEYS.TOKENS, serverUrl)
      );
      let parsed = null;
      if (raw) {
        try {
          parsed = OAuthTokensSchema.safeParse(JSON.parse(raw));
        } catch {
          return fail("Authenticated but the saved tokens were unreadable");
        }
      }
      if (!parsed || !parsed.success) {
        return fail("Authenticated but no tokens were saved");
      }
      if (inPopup) {
        postOAuthResultToOpener({
          type: OAUTH_POPUP_MESSAGE,
          ok: true,
          serverUrl,
          tokens: parsed.data
        });
        return;
      }
      toast({
        title: "Success",
        description: "Successfully authenticated with OAuth",
        variant: "default"
      });
      onConnect(serverUrl);
    };
    handleCallback().finally(() => {
      if (!inPopup) {
        window.history.replaceState({}, document.title, "/");
      }
    });
  }, [toast, onConnect]);
  return /* @__PURE__ */ jsxRuntimeExports.jsx("div", { className: "flex items-center justify-center h-screen", children: /* @__PURE__ */ jsxRuntimeExports.jsx("p", { className: "text-lg text-gray-500", children: "Processing OAuth callback..." }) });
};
export {
  OAuthCallback as default
};
