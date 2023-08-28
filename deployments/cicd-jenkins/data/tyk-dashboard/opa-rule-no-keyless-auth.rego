deny["API must not allow unauthenticated access"] {
	# Intent is to to update API
	request_permission[_] == "apis"
	request_intent == "write"

	# if API is tagged as requiring auth
	contains(input.request.body.api_definition.name, "#auth-required")

	# enforce that keyless auth is not allowed
	input.request.body.api_definition.use_keyless == true
}