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

# The largest CV accepted, in bytes.
public const MAX_CV_BYTES = 5 * 1024 * 1024;

# The largest request body accepted: the CV plus the other form fields.
public const MAX_REQUEST_BYTES = 6 * 1024 * 1024;

# The details an applicant submits, with the CV's raw bytes.
public type ApplicationForm record {|
    string firstName;
    string lastName;
    string email;
    string phone;
    string address;
    string university?;
    byte[] cv;
|};
