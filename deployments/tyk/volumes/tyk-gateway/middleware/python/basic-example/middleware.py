from tyk.decorators import *
from gateway import TykGateway as tyk


@Hook
def PreMiddlewareFunction(request, session, spec):
    tyk.log("Python plugin: Pre hook called", "info")
    request.add_header("Python-Plugin-Pre-Hook", "Pre Hook")
    return request, session


@Hook
def PostKeyAuthMiddlewareFunction(request, session, spec):
    tyk.log("Python plugin: PostKeyAuth hook called", "info")
    request.add_header("Python-Plugin-PostKeyAuth-Hook", "PostKeyAuth Hook")
    return request, session


@Hook
def PostMiddlewareFunction(request, session, spec):
    tyk.log("Python plugin: Post hook called", "info")
    request.add_header("Python-Plugin-Post-Hook", "Post Hook")
    return request, session


@Hook
def ResponseMiddlewareFunction(request, response, session, metadata, spec):
    tyk.log("Python plugin: Response hook called", "info")
    tyk.log("Python plugin: Response status code: {0}".format(
        response.status_code), "info")
    response.headers["Python-Plugin-Response-Hook"] = "Response Hook"
    return response
