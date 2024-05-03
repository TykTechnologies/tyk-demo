# Python gRPC Plugin for Tyk Gateway

This repository implements a basic Tyk Python gRPC server that listens for requests received from the Tyk Gateway and outputs the incoming request payload in JSON format. It also implements a custom authentication plugin that verifies an HMAC signature and key. 

To accomplish this, a gRPC server has been implemented that complies with Tyk's [ServiceDispatcher](https://github.com/TykTechnologies/tyk/blob/master/coprocess/proto/coprocess_object.proto) protobuf service.

This deployment contains the following files:
- `tyk_async_server.py` contains the implementation of a Python gRPC server that implements the [ServiceDispatcher](https://github.com/TykTechnologies/tyk/blob/master/coprocess/proto/coprocess_object.proto) interface. The server implementation also has a custom authentication plugin for verifying HMAC signature and key ID.
- `Dockerfile` that supports building a docker image to install Python grpcio-tools and generates the protbuf bindings for Python. When a container is run for this image it starts the Python gRPC server when run.
- `hmac.sh` is a bash script in the scripts folder that allows sending a HMAC signed request to the *python-grpc-custom-auth* API for a given key ID and secret. The API verifies the HMAC signature and key.

## Prerequisites installed by Docker

### 3rd Party Tools
- [poetry](https://python-poetry.org/) - Python dependency management CLI
- [Python 3.12](https://www.python.org/downloads/release/python-3120/?ref=upstract.com)

### Python Dependencies
- [grpcio](https://grpc.io/) - Required for generating the Python bindings.
- [grpc-reflection](https://github.com/grpc/grpc/blob/master/doc/python/server_reflection.md) - Used to allow server introspection so that endpoints can be listed/called from gRPC clients.
- [protobuf](https://googleapis.dev/python/protobuf/latest/) - The protobuf API for Python.


## Quickstart - Running The Server

Enter the following command `./up.sh python-grpc-server` to start the Python gRPC server. This will use the Dockerfile to build a custom image that will generate the Python bindings for the gRPC server. When the Docker container is started it will start the gRPC server.

## Configure Tyk Gateway To Serve Plugins Using The gRPC Server

Tyk Gateway needs to be configured with *coprocess* enabled in addition to the URL of the gRPC server. This has been done for you in the tyk-demo repository.

Within the root of the *tyk.conf* file, add the following:

```json
"coprocess_options": {
  "enable_coprocess":   true,
  "coprocess_grpc_server": "tcp://<host>:<port>"
}
```

Alternatively, the following environment variables can be set in your .env file:

```bash
TYK_GW_COPROCESSOPTIONS_ENABLECOPROCESS=true
TYK_GW_COPROCESSOPTIONS_COPROCESSGRPCSERVER=tcp://tyk-python-grpc-server:50051
```

## Configure Your API To Use The gRPC Plugin

Create a Tyk Classic API or a Tyk OAS API and configure plugins. The plugin driver should be set to *grpc*. 

### Tyk Classic API

gRPC plugins can be configured within the *custom_middleware* section of the *api_definition*:

```json
{
  "created_at": "2024-03-231T12:49:52Z",
  "api_model": {},
  "api_definition": {
    ...
    ...
    "custom_middleware": {
      "pre": [
        {
          "disabled": false,
          "name": "MyPreRequestPlugin",
          "path": "",
          "require_session": false,
          "raw_body_only": false
        }
      ],
      "post": [],
      "post_key_auth": [],
      "auth_check": {
        "disabled": false,
        "name": "",
        "path": "",
        "require_session": false,
        "raw_body_only": false
      },
      "response": [
        {
          "disabled": false,
          "name": "MyResponsePlugin",
          "path": "",
          "require_session": true,
          "raw_body_only": false
        }
      ],
      "driver": "grpc",
      "id_extractor": {
        "disabled": false,
        "extract_from": "",
        "extract_with": "",
        "extractor_config": {}
      }
    }
}
```

In the above listing, the plugin *driver* parameter has been set to *grpc*. Two plugins are configured within the *custom_middleware* section: a *pre request* plugin and a *response* plugin.

The *response* plugin is configured with *require_session* enabled, so that Tyk Gateway will send details for the authenticated key / user with the gRPC request. Note, this is not configured
for *pre request* plugins that are triggered before authentication in the request lifecycle.

Tyk Gateway will forward details of an incoming request to the gRPC server, for each plugin.

### Tyk OAS API

To quickly get started, a Tyk OAS API can be created by importing the infamous pet store OAS [JSON](https://petstore3.swagger.io/api/v3/openapi.json) schema. Then the [findByStatus](https://petstore3.swagger.io/api/v3/pet/findByStatus?status=available) endpoint can be used for testing. The resulting Tyk OAS API Definition contains the OAS JSON schema with an *x-tyk-api-gateway* section appended.

The gRPC plugin can be configured within the *middleware* section of *x-tyk-api-gateway*:

```json
"middleware": {
  "global": {
    "pluginConfig": {
      "driver": "grpc"
    },
    "cors": {
      "enabled": false,
      "maxAge": 24,
      "allowedHeaders": [
        "Accept",
        "Content-Type",
        "Origin",
        "X-Requested-With",
        "Authorization"
      ],
      "allowedOrigins": [
        "*"
      ],
      "allowedMethods": [
        "GET",
        "HEAD",
        "POST"
      ]
    },
    "prePlugin": {
      "plugins": [
        {
          "enabled": true,
          "functionName": "MyPreRequestPlugin",
          "path": ""
        }
      ]
    },
    "responsePlugin": {
      "plugins": [
        {
          "enabled": true,
          "functionName": "MyResponsePlugin",
          "path": "",
          "requireSession": true
        }
      ]
    }
  }
}
```

In the above listing, the plugin *driver* parameter has been set to *grpc*. Two plugins are configured within the *middleware* section: a *pre request* plugin and a *response* plugin.

The *response* plugin is configured with *requireSession* enabled, so that Tyk Gateway will send details for the authenticated key / user with the gRPC request. Note, this is not configurable
for *pre request* plugins that are triggered before authentication in the request lifecycle.

Tyk Gateway will forward details of an incoming request to the gRPC server, for each plugin.


## Example Payload Sent To The gRPC Server From Tyk Gateway

The example payload listed below was dispatched by Tyk Gateway to the gRPC server before the request was sent upstream to the *findByStatus* endpoint of the pet store server.

```json
{
  "hookType": "Response",
  "hookName": "MyResponsePlugin",
  "request": {
    "headers": {
      "User-Agent": "curl/8.1.2",
      "Host": "localhost:8080",
      "Accept": "*/*"
    },
    "url": "http://petstore3.swagger.io/api/v3/pet/findByStatus?status=available",
    "params": {
      "status": "available"
    },
    "returnOverrides": {
      "responseCode": -1
    },
    "method": "GET",
    "requestUri": "/pet/findByStatus?status=available",
    "scheme": "http"
  },
  "session": {
    "basicAuthData": {},
    "jwtData": {},
    "monitor": {}
  },
  "spec": {
    "bundle_hash": "d41d8cd98f00b204e9800998ecf8427e",
    "OrgID": "5e9d9544a1dcd60001d0ed20",
    "APIID": "ce6528c0af7b43206b9cf736a5e5d1b4"
  },
  "response": {
    "statusCode": 301,
    "rawBody": "PGh0bWw+DQo8aGVhZD48dGl0bGU+MzAxIE1vdmVkIFBlcm1hbmVudGx5PC90aXRsZT48L2hlYWQ+DQo8Ym9keT4NCjxjZW50ZXI+PGgxPjMwMSBNb3ZlZCBQZXJtYW5lbnRseTwvaDE+PC9jZW50ZXI+DQo8L2JvZHk+DQo8L2h0bWw+DQo=",
    "body": "<html>\r\n<head><title>301 Moved Permanently</title></head>\r\n<body>\r\n<center><h1>301 Moved Permanently</h1></center>\r\n</body>\r\n</html>\r\n",
    "headers": {
      "Date": "Sat, 24 Feb 2024 11:33:36 GMT",
      "Server": "awselb/2.0",
      "Content-Length": "134",
      "Content-Type": "text/html",
      "Location": "https://petstore3.swagger.io:443/api/v3/pet/findByStatus?status=available",
      "Connection": "keep-alive"
    },
    "multivalueHeaders": [
      {
        "key": "Date",
        "values": [
          "Sat, 24 Feb 2024 11:33:36 GMT"
        ]
      },
      {
        "key": "Content-Type",
        "values": [
          "text/html"
        ]
      },
      {
        "key": "Content-Length",
        "values": [
          "134"
        ]
      },
      {
        "key": "Connection",
        "values": [
          "keep-alive"
        ]
      },
      {
        "key": "Location",
        "values": [
          "https://petstore3.swagger.io:443/api/v3/pet/findByStatus?status=available"
        ]
      },
      {
        "key": "Server",
        "values": [
          "awselb/2.0"
        ]
      }
    ]
  }
}
```

## FAQs

### What Is The Tyk gRPC protobuf Service Interface That I Should Implement?

The *Dispatcher* gRPC service and supporting data structures are located within the *coprocess_object.proto* file:

```protobuf
service Dispatcher {

  /**
   * @brief Accepts and returns an \ref Object
   */
  rpc Dispatch (Object) returns (Object) {}

  /**
   * @brief Dispatches an event to the target language
   */
  rpc DispatchEvent (Event) returns (EventReply) {}
}
```

This contains the following methods:
- **Dispatch**: Called by Tyk Gateway for every configured plugin for every request.
- **DispatchEvent**: Provides a mechanism for the gRPC server to receive Tyk events.

### How Do I Implement The Python Tyk gRPC Plugin Service?

Firstly, you need to use the *protoc* compiler to generate the supporting Python classes. These classes allow serialisation
of protobuf messages. The *protoc* compiler will also generate a base class for your gRPCServer.

Inspect the generated file, *coprocess_object_pb2_grpc.py*. It contains a class named *DispatcherServicer*:

```python
class DispatcherServicer(object):
    """*
    @brief GRPC server interface

    The server interface that must be implemented by the target language
    """

    def Dispatch(self, request, context):
        """*
        @brief Accepts and returns an \ref Object
        """
        context.set_code(grpc.StatusCode.UNIMPLEMENTED)
        context.set_details('Method not implemented!')
        raise NotImplementedError('Method not implemented!')

    def DispatchEvent(self, request, context):
        """*
        @brief Dispatches an event to the target language
        """
        context.set_code(grpc.StatusCode.UNIMPLEMENTED)
        context.set_details('Method not implemented!')
        raise NotImplementedError('Method not implemented!')
```

Notice that comments from the protobuf file have been included in the generated Python class.

Finally, write a class that inherits from the *DispatcherServicer* base class, implementing the *Dispatch* and *DispatchEvent* methods. An example implementation, included in *tyk_async_server.py*, is listed below:

```python
class PythonDispatcher(coprocess_object_pb2_grpc.DispatcherServicer):
    async def Dispatch(
        self, object: coprocess_object_pb2.Object, context: grpc.aio.ServicerContext
    ) -> coprocess_object_pb2.Object:
        logging.info(f"REQUEST\n{MessageToJson(object)}\n")

        if object.hook_type == HookType.Pre:
            logging.info(f"Pre plugin name: {object.hook_name}")
            logging.info(f"Activated Pre Request plugin from API: {object.spec.get('APIID')}")
        elif object.hook_type == HookType.Response:
            logging.info(f"Response plugin name: {object.hook_name}")
            logging.info(f"Activated Response plugin from API: {object.spec.get('APIID')}")

        return object

    async def DispatchEvent(
        self, event: coprocess_object_pb2.Event, context: grpc.aio.ServicerContext
    ) -> coprocess_object_pb2.EventReply:

        event = json.loads(event.payload)
        logging.info(f"RECEIVED EVENT: {event}")
        return coprocess_object_pb2.EventReply()
```

- The *Dispatch* method uses the *MessageToJson* function provided, by Google's protobuf API, to output the message
received from the Gateway in JSON format. The plugin hook type is inspected in the request payload and an output message is displayed to indicate the type of plugin received.
- The *DispatchEvent* method outputs the JSON payload of an event for dispatch. 
