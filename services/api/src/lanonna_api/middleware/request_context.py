from __future__ import annotations

import uuid

from lanonna_api.request_context import set_request_id
from starlette.middleware.base import BaseHTTPMiddleware
from starlette.requests import Request
from starlette.responses import Response

_REQUEST_ID_HEADER = "X-Request-Id"


class RequestContextMiddleware(BaseHTTPMiddleware):
    async def dispatch(self, request: Request, call_next) -> Response:
        request_id = request.headers.get(_REQUEST_ID_HEADER) or str(uuid.uuid4())
        request.state.request_id = request_id
        set_request_id(request_id)
        response = await call_next(request)
        response.headers[_REQUEST_ID_HEADER] = request_id
        return response
