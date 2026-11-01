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

# OAuth2 client auth configurations.
type Oauth2Config record {|
    # OAuth2 token endpoint
    string tokenUrl;
    # OAuth2 client ID
    string clientId;
    # OAuth2 client secret
    string clientSecret;
|};

# Retry config for the graphql client.
type GraphQlRetryConfig record {|
    # Retry count
    int count = 3;
    # Retry interval
    decimal interval = 3.0;
    # Retry backOff factor
    float backOffFactor = 2.0;
    # Retry max interval
    decimal maxWaitInterval = 20.0;
|};

# Employee fields the reminder needs from the HR entity service.
public type Employee record {|
    # First name of the employee
    string? firstName;
    # Last name of the employee
    string? lastName;
    # Work email of the employee's current lead
    string? managerEmail;
|};

# GraphQL single employee response.
type SingleEmployeeResponse record {|
    # Response data wrapper
    record {|
        # Employee data
        Employee? employee;
    |} data;
|};
