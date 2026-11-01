// Copyright (c) 2026 WSO2 LLC. (https://www.wso2.com).
//
// WSO2 LLC. licenses this file to you under the Apache License,
// Version 2.0 (the "License"); you may not use this file except
// in compliance with the License.
// You may obtain a copy of the License at
//
// http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing,
// software distributed under the License is distributed on an
// "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
// KIND, either express or implied.  See the License for the
// specific language governing permissions and limitations
// under the License.

import ballerina/http;
import ballerina/uuid;

# The header that carries the request id to and from other services.
public const REQUEST_ID_HEADER = "X-Request-ID";

const CTX_REQUEST_ID = "careers-app-request-id";

// Letters, digits and "-" only, so a caller's id cannot forge or split log lines.
final string:RegExp REQUEST_ID_PATTERN = re `[A-Za-z0-9-]{8,64}`;

# The caller's request id when it is well formed, otherwise a new one.
public isolated function requestIdFrom(string? incoming) returns string {
    if incoming is string && REQUEST_ID_PATTERN.isFullMatch(incoming) {
        return incoming;
    }
    return uuid:createType4AsString();
}

# Gives every request an id, so it can be followed through the logs of this service and the ones it calls.
public isolated service class RequestIdInterceptor {
    *http:RequestInterceptor;

    isolated resource function 'default [string... path](http:RequestContext ctx, http:Request req)
            returns http:NextService|error? {
        string|http:HeaderNotFoundError incoming = req.getHeader(REQUEST_ID_HEADER);
        ctx.set(CTX_REQUEST_ID, requestIdFrom(incoming is string ? incoming : ()));
        return ctx.next();
    }
}

# The id given to the request by `RequestIdInterceptor`, or "unknown".
public isolated function requestIdOf(http:RequestContext ctx) returns string {
    string|error id = ctx.getWithType(CTX_REQUEST_ID);
    return id is string ? id : "unknown";
}
