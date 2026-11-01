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

import wso2/careers_app.types;

import ballerina/http;


const CTX_USER = "careers-app-user";
const CTX_TOKEN = "careers-app-token";

# The caller's validated identity.
public type AsgardeoJwt record {|
    string sub;
|};

# The identity provider refused the caller's access token.
public type UserInfoRefused distinct error;

# What the identity provider knows about the caller; an empty text means it does not know.
public type CallerDetails record {|
    string email = "";
    string firstName = "";
    string lastName = "";
    string gender = "";
    string contactNo = "";
|};

# Asgardeo connection details for token validation.
public type AuthConfig record {|
    string jwksUrl;
    string issuer;
    string audience;
    string userInfoUrl;
|};

public type AppUnauthorizedError record {|
    *http:Unauthorized;
    types:ErrorPayload body;
|};

public type AppTooManyRequestsError record {|
    *http:TooManyRequests;
    types:ErrorPayload body;
|};
