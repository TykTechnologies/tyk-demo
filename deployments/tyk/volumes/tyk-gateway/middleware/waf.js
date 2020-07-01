var Waf = new TykJS.TykMiddleware.NewMiddleware({});

Waf.NewProcessRequest(function(request, session, config) {
    
    response = sendRequestToWaf(request)

    if (response) {
        log('request failed inspection!')
        log(JSON.stringify(response))
        request.ReturnOverrides = {
            ResponseCode: 400,
            ResponseError: "Bad request!"
        }
        return Waf.ReturnData(request, {});
    }

    log('Passed WAF')

	return Waf.ReturnData(request, {});
});

// Returns an error object if malicious activity is found
// Otherwise, returns null
function sendRequestToWaf(request){
    // Handle Query Params, send query params only, not endpoint
    var params = request.RequestURI.split('?')[1];
    params = params || '';  // if undefined, use empty string

    newRequest = {
        "Method": request.Method,
        "Domain": "http://waf", // WAF URL
        "resource": '/?' + params 
    };

    var wafResponse = JSON.parse(TykMakeHttpRequest(JSON.stringify(newRequest)));

    if ( wafResponse.Code !== 200 ){
        return wafResponse;
    }

    return null;
}
