// ---- Sample middleware creation by end-user -----
var exampleJavaScriptMiddlewarePreHook = new TykJS.TykMiddleware.NewMiddleware({});
var exampleJavaScriptMiddlewarePostHook = new TykJS.TykMiddleware.NewMiddleware({});

exampleJavaScriptMiddlewarePreHook.NewProcessRequest(function(request, session) {
    // You can log to Tyk console output by calling the built-in log() function:
    log("Hello from the Tyk JavaScript middleware pre hook function")
    
    // Add and remove request headers
    request.SetHeaders["User-Agent"] = "Tyk-JavaScript-Middleware";
    request.DeleteHeaders.push("Deleted");
    
    // Add and remove request parameters
    request.AddParams["added"] = "123";
    request.DeleteParams.push("deleted");
    
    // Change the body data
    request.Body = "Request body set by pre middleware"

    // Change the requested URL
    request.URL = "/anything/post";

    // You must return both the request and session metadata 
    return exampleJavaScriptMiddlewarePreHook.ReturnData(request, {});
});

exampleJavaScriptMiddlewarePostHook.NewProcessRequest(function(request, session, spec) {
  // You can log to Tyk console output by calling the built-in log() function:
  log("Hello from the Tyk JavaScript middleware post hook function")

  request.SetHeaders["config-data"] = spec.config_data.config_key;

  // You must return both the request and session metadata    
  return exampleJavaScriptMiddlewarePostHook.ReturnData(request, {});
});

// Log that middleware is initialised
log("JavaScript middleware is initialised");