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


import { formatDate } from "./PendingChangesBanner";

describe("formatDate", () => {
  it("shows the day stored, whatever zone the reader is in", () => {
    // A date-only string parses as midnight UTC; read in a zone west of UTC it would
    // otherwise come out as the day before.
    expect(formatDate("2026-10-16")).toContain("16");
  });

  it("is not labelled UTC, since the date is the employee's own local day", () => {
    expect(formatDate("2026-10-16")).not.toContain("UTC");
  });
});
