package main

import (
	"encoding/base64"
	"encoding/json"
	"net/http"
	"strings"

	"github.com/TykTechnologies/tyk/log"
)

var logger = log.Get()

// This function shows how a JWT provided as a HTTP header can be parsed and data extracted from it
func ParseJWT(rw http.ResponseWriter, r *http.Request) {
	// Get the Authorization header value
	authHeader := r.Header.Get("Authorization")
	logger.Info("Authorization header: ", authHeader)

	// get each part of the JWT
	jwtParts := strings.Split(authHeader, ".")

	for index := range jwtParts {
		logger.Info("JWT part ", index, " = ", jwtParts[index])
	}

	// decode the payload
	decodedJWTPayload, err := base64.RawStdEncoding.DecodeString(jwtParts[1])

	if err != nil {
		logger.Info("Error decoding JWT payload: ", err)
	}

	logger.Info("Decoded JWT payload: ", string(decodedJWTPayload))

	// unmarshal into a string map
	jwtPayload := make(map[string]interface{})
	err = json.Unmarshal(decodedJWTPayload, &jwtPayload)

	if err != nil {
		logger.Info("Error unmarshalling JWT: ", err)
	}

	// read the "pol" value
	policyId := jwtPayload["pol"]
	logger.Info("Policy Id: ", policyId)

	// add the policy Id to the request
	r.Header.Add("X-JWT-Policy-Id", policyId.(string))
}

// Called once plugin is loaded, this is where we put all initialization work for plugin
// i.e. setting exported functions, setting up connection pool to storage and etc.
func init() {
	logger.Info("Initialising Parse JWT Go Plugin")
}

func main() {}
