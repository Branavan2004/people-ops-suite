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

// The same shape the backend accepts, so a typo is caught before the CV is uploaded.
const EMAIL_PATTERN = /^[^\s@]+@[^\s@.]+(\.[^\s@.]+)+$/;

export const isValidEmail = (email: string): boolean => email.length <= 254 && EMAIL_PATTERN.test(email.trim());

// The email in the ?email= value of a link. A "+" the sender did not encode as %2B is read as a space, which an email
// cannot contain, so each space is put back as "+" and a plus-addressed email keeps its sign-in hint.
export const emailFromLink = (value: string | null): string => (value ?? "").trim().replace(/ /g, "+");
