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

import { emailFromLink, isValidEmail } from "@utils/email";

describe("emailFromLink", () => {
  it("gives back a plus the sender did not encode, which a link reader turns into a space", () => {
    const params = new URLSearchParams("?email=name+tag@example.com");
    expect(emailFromLink(params.get("email"))).toBe("name+tag@example.com");
    expect(isValidEmail(emailFromLink(params.get("email")))).toBe(true);
  });

  it("keeps a plus the sender encoded as %2B", () => {
    const params = new URLSearchParams("?email=name%2Btag@example.com");
    expect(emailFromLink(params.get("email"))).toBe("name+tag@example.com");
  });

  it("is empty when the link has no email", () => {
    expect(emailFromLink(null)).toBe("");
  });
});

describe("isValidEmail", () => {
  it("accepts a normal address", () => {
    expect(isValidEmail("name@example.com")).toBe(true);
    expect(isValidEmail("first.last+tag@mail.example.co.uk")).toBe(true);
  });

  it("ignores spaces around the address", () => {
    expect(isValidEmail("  name@example.com  ")).toBe(true);
  });

  it.each(["", "abc", "a@b", "@example.com", "name@", "a b@example.com", "a@@example.com", "a@.example.com", "a@example."])(
    "rejects %j",
    (email) => {
      expect(isValidEmail(email)).toBe(false);
    },
  );

  it("rejects an address longer than 254 characters", () => {
    expect(isValidEmail(`${"a".repeat(250)}@example.com`)).toBe(false);
  });
});
