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

# Whether the value is a vacancy id (digits only); nothing else may reach the upstream URL or count as a public route.
public isolated function isValidJobId(string jobId) returns boolean => re `[0-9]+`.isFullMatch(jobId);

# The text with every email address, plain or URL-encoded, replaced, so that it is safe to write to a log.
public isolated function withoutEmails(string text) returns string =>
    re `[^\s/?&=]+(%40|@)[^\s/?&=]+`.replaceAll(text, "{email}");

# The text with email addresses and phone numbers replaced, so that an upstream reply or an error quoting a value is
# safe to write to a log.
public isolated function withoutPersonalData(string text) returns string =>
    re `\+?\d[\d\s\-()]{5,}\d`.replaceAll(withoutEmails(text), "{phone}");
