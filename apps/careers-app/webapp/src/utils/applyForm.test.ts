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

import { describe, expect, it } from "vitest";

import { type ApplyFormState, isApplyFormComplete } from "@utils/applyForm";

const complete: ApplyFormState = {
  firstName: "Alice",
  lastName: "Bob",
  email: "alice@example.com",
  countryIso: "LK",
  phone: "771234567",
  address: "45 Galle Road, Colombo 03",
  university: "",
  isInternship: false,
  hasCv: true,
  authorized: "yes",
  consentData: true,
  consentChecks: true,
};

describe("isApplyFormComplete", () => {
  it("accepts a form with everything given and the two required consents ticked", () => {
    expect(isApplyFormComplete(complete)).toBe(true);
  });

  it("needs the consent to use the personal data", () => {
    expect(isApplyFormComplete({ ...complete, consentData: false })).toBe(false);
  });

  it("needs the consent to the checks", () => {
    expect(isApplyFormComplete({ ...complete, consentChecks: false })).toBe(false);
  });

  it("needs an answer to the work authorization question, whichever it is", () => {
    expect(isApplyFormComplete({ ...complete, authorized: "" })).toBe(false);
    expect(isApplyFormComplete({ ...complete, authorized: "no" })).toBe(true);
  });

  it("needs a CV and a valid email", () => {
    expect(isApplyFormComplete({ ...complete, hasCv: false })).toBe(false);
    expect(isApplyFormComplete({ ...complete, email: "alice" })).toBe(false);
  });

  it("needs an address, or a university for an internship", () => {
    expect(isApplyFormComplete({ ...complete, address: " " })).toBe(false);
    expect(isApplyFormComplete({ ...complete, isInternship: true, address: "", university: "Moratuwa" })).toBe(true);
    expect(isApplyFormComplete({ ...complete, isInternship: true, university: "" })).toBe(false);
  });
});
