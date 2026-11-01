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

configurable EmailServiceConfig emailServiceConfig = ?;
# When true, every reminder goes only to `debugRecipients`, with no CC (for non-production environments).
configurable boolean isDebug = false;
# Recipients of every reminder while `isDebug` is true.
configurable string[] debugRecipients = [];

# Email HTTP client, shared across all scheduled jobs.
@display {
    label: "Email Notifications Service",
    id: "infra/email-notifications-service"
}
final http:Client emailClient = check new (emailServiceConfig.emailServiceEndpoint, {
    auth: {
        ...emailServiceConfig.oauthConfig
    },
    timeout: 15.0,
    httpVersion: http:HTTP_1_1,
    http1Settings: {
        keepAlive: http:KEEPALIVE_NEVER
    },
    retryConfig: {
        count: 5,
        interval: 3.0,
        backOffFactor: 2.0,
        maxWaitInterval: 30.0,
        statusCodes: [
            http:STATUS_INTERNAL_SERVER_ERROR,
            http:STATUS_BAD_GATEWAY,
            http:STATUS_SERVICE_UNAVAILABLE,
            http:STATUS_GATEWAY_TIMEOUT
        ]
    }
});
