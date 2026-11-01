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

import { type RouteData, dataNeededBy } from "@utils/routeData";

const none: RouteData = {
  jobs: false,
  orgStructure: false,
  jobDetails: false,
  applications: false,
  profile: false,
};

describe("dataNeededBy", () => {
  it("needs nothing when no matched route declares anything", () => {
    expect(dataNeededBy([])).toEqual(none);
    expect(dataNeededBy([{}, { handle: undefined }, { handle: {} }])).toEqual(none);
  });

  it("needs what the matched route declares", () => {
    expect(dataNeededBy([{ handle: { needs: ["jobs", "applications"] } }])).toEqual({
      ...none,
      jobs: true,
      applications: true,
    });
  });

  it("combines what a route and the routes around it declare", () => {
    expect(
      dataNeededBy([
        { handle: { needs: ["profile"] } },
        { handle: undefined },
        { handle: { needs: ["jobs"] } },
      ]),
    ).toEqual({ ...none, profile: true, jobs: true });
  });
});
