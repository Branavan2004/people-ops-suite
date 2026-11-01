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

# The response for an application the ATS did not accept. Its own reply is never passed on.
public isolated function applyFailure(int upstreamStatus)
        returns http:NotFound|http:Conflict|http:BadRequest|http:GatewayTimeout|http:BadGateway {
    match upstreamStatus {
        404 => {
            return <http:NotFound>{body: {message: "This vacancy was not found or is no longer open."}};
        }
        409 => {
            return <http:Conflict>{body: {message: "You have already applied for this role."}};
        }
        400|422 => {
            return <http:BadRequest>{body: {message: "The application was not accepted. Please check your details."}};
        }
        503|504 => {
            return <http:GatewayTimeout>{body: {message: "Upstream service unreachable"}};
        }
    }
    return <http:BadGateway>{body: {message: "The application could not be submitted. Please try again."}};
}
