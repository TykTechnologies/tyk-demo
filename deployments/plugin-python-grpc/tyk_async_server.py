"""Python AsyncIO Dispatcher"""

import asyncio
import base64
import hashlib
import hmac
import json
import re
import signal
import logging
import urllib.parse

import grpc
from google.protobuf.json_format import MessageToJson
from grpc_reflection.v1alpha import reflection
import coprocess_object_pb2_grpc
import coprocess_object_pb2
from coprocess_common_pb2 import HookType
from coprocess_session_state_pb2 import SessionState

SECRET = "c2VjcmV0"
VALID_TOKEN = "eyJvcmciOiI1ZTlkOTU0NGExZGNkNjAwMDFkMGVkMjAiLCJpZCI6ImdycGNfaG1hY19rZXkiLCJoIjoibXVybXVyNjQifQ=="


def set_response_error(object: coprocess_object_pb2.Object, code: int, message: str) -> None:
    object.request.return_overrides.response_code = code
    object.request.return_overrides.response_error = message


def parse_auth_header(auth_header: str) -> dict[str,str]:
    pattern = r'(\w+)\s*=\s*"([^"]+)"'

    matches = re.findall(pattern, auth_header)

    parsed_data = dict(matches)

    return parsed_data


def generate_hmac_signature(algorithm: str, date_string: str, secret_key: str) -> str:

    if algorithm == "hmac-sha256":
        hash_algorithm = hashlib.sha256
    elif algorithm == "hmac-sha512":
        hash_algorithm = hashlib.sha512
    else:
        raise ValueError("Unsupported hash algorithm")

    base_string = f"date: {date_string}"

    logging.info(f"generating signature from: {base_string}")
    hmac_signature = hmac.new(secret_key.encode(), base_string.encode(), hash_algorithm)

    return base64.b64encode(hmac_signature.digest()).decode()


def verify_hmac_signature(algorithm: str, signature: str, source_string) -> bool:

    expected_signature = generate_hmac_signature(algorithm, source_string, SECRET)
    received_signature = urllib.parse.unquote(signature)

    if expected_signature != received_signature:
        error = f"Signatures did not match\nreceived: {received_signature}\nexpected: {expected_signature}"
        logging.error(error)
    else:
        logging.info("Signatures matched!")

    return expected_signature == received_signature


def authenticate(object: coprocess_object_pb2.Object) -> coprocess_object_pb2.Object:
    keys_to_check = ["keyId", "algorithm", "signature"]

    auth_header = object.request.headers.get("Authorization")
    date_header = object.request.headers.get("Date")

    parse_dict = parse_auth_header(auth_header)

    if not all(key in parse_dict for key in keys_to_check) or not all([auth_header, date_header]):
        set_response_error(object, 400, "Custom middleware: Bad request")
        return object

    try:
        signature_valid = verify_hmac_signature(
            parse_dict["algorithm"],
            parse_dict["signature"],
            date_header
        )
    except ValueError:
        set_response_error(object, 400, "Bad HMAC request, unsupported algorithm")
        return object

    if not signature_valid or parse_dict["keyId"] != VALID_TOKEN:
        set_response_error(object, 401, "Custom middleware: Not authorized")
    else:
        new_session = SessionState()
        new_session.hmac_enabled = True
        new_session.hmac_secret = SECRET

        object.metadata["token"] = VALID_TOKEN
        object.session.CopyFrom(new_session)

    return object


class PythonDispatcher(coprocess_object_pb2_grpc.DispatcherServicer):
    async def Dispatch(
        self, object: coprocess_object_pb2.Object, context: grpc.aio.ServicerContext
    ) -> coprocess_object_pb2.Object:
        logging.info(f"STATE for {object.hook_name}\n{MessageToJson(object)}\n")

        if object.hook_type == HookType.Pre:
            logging.info(f"Pre plugin name: {object.hook_name}")
            object.request.add_params["new-param"] = "new-value"
            object.request.extended_params["extended-param"] = "extended-value"
            logging.info(f"Activated Pre Request plugin from API: {object.spec.get('APIID')}")
        elif object.hook_type == HookType.CustomKeyCheck:
            logging.info(f"CustomAuth plugin: {object.hook_name}")
            logging.info(f"Activated CustomAuth plugin from API: {object.spec.get('APIID')}")

            authenticate(object)
        elif object.hook_type == HookType.PostKeyAuth:
            object.request.delete_params.append("new-param")
            logging.info(f"PostKeyAuth plugin name: {object.hook_name}")
            logging.info(f"Activated PostKeyAuth plugin from API: {object.spec.get('APIID')}")
        elif object.hook_type == HookType.Post:
            logging.info(f"Post plugin name: {object.hook_name}")
            logging.info(f"Activated Post plugin from API: {object.spec.get('APIID')}")
        elif object.hook_type == HookType.Response:
            logging.info(f"Response plugin name: {object.hook_name}")
            logging.info(f"Activated Response plugin from API: {object.spec.get('APIID')}")

        logging.info("--------\n")
        return object

    async def DispatchEvent(
        self, event: coprocess_object_pb2.Event, context: grpc.aio.ServicerContext
    ) -> coprocess_object_pb2.EventReply:

        event = json.loads(event.payload)
        logging.info(f"RECEIVED EVENT: {event}")
        return coprocess_object_pb2.EventReply()


async def serve() -> None:
    server = grpc.aio.server()

    coprocess_object_pb2_grpc.add_DispatcherServicer_to_server(
        PythonDispatcher(), server
    )
    listen_addr = "[::]:50051"

    SERVICE_NAMES = (
        coprocess_object_pb2.DESCRIPTOR.services_by_name["Dispatcher"].full_name,
        reflection.SERVICE_NAME,
    )
    reflection.enable_server_reflection(SERVICE_NAMES, server)

    server.add_insecure_port(listen_addr)
    logging.info("Starting server on %s", listen_addr)
    await server.start()
    await server.wait_for_termination()


async def shutdown_server(server) -> None:
    logging.info("Shutting down server...")
    await server.stop(None)


def handle_sigterm(sig, frame) -> None:
    asyncio.create_task(shutdown_server(server))


async def handle_sigint() -> None:
    loop = asyncio.get_running_loop()
    for sig in (signal.SIGINT, signal.SIGTERM):
        loop.add_signal_handler(sig, loop.stop)


if __name__ == '__main__':
    logging.basicConfig(level=logging.INFO)

    server = None

    signal.signal(signal.SIGTERM, handle_sigterm)

    try:
        asyncio.get_event_loop().run_until_complete(serve())
    except KeyboardInterrupt:
        pass
