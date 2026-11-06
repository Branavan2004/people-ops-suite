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

import { summariseInternMonth } from "@utils/employeeHub/internMonthSummary";

const intern = (id: string, joinedDate: string | null, endDate: string | null) => ({ id, joinedDate, endDate });
const ids = (rows: { id: string }[]) => rows.map((r) => r.id).sort();

describe("summariseInternMonth", () => {
  // Selected day mid-month: the summary covers the whole month regardless.
  const nov = new Date(2026, 10, 18);

  const interns = [
    intern("carry-continues", "2026-06-01", "2026-12-31"),
    intern("carry-leaves", "2026-05-01", "2026-11-20"),
    intern("carry-ends-on-1st", "2026-05-01", "2026-11-01"),
    intern("ended-before", "2026-01-01", "2026-10-31"),
    intern("joins-continues", "2026-11-03", "2027-05-02"),
    intern("joins-leaves", "2026-11-02", "2026-11-28"),
    intern("joins-last-day", "2026-11-30", "2027-05-29"),
    intern("joins-next-month", "2026-12-01", "2027-06-01"),
    intern("joins-no-end", "2026-11-10", null),
    intern("carry-no-end", "2026-04-01", null),
    intern("no-dates", null, null),
  ];

  const s = summariseInternMonth(interns, nov);

  it("matches the sheet's definitions", () => {
    expect(ids(s.fromPreviousMonth)).toEqual(["carry-continues", "carry-ends-on-1st", "carry-leaves"]);
    expect(ids(s.joiningThisMonth)).toEqual(["joins-continues", "joins-last-day", "joins-leaves", "joins-no-end"]);
    expect(ids(s.leavingThisMonth)).toEqual(["carry-ends-on-1st", "carry-leaves", "joins-leaves"]);
    expect(ids(s.proceeding)).toEqual(["carry-continues", "joins-continues", "joins-last-day"]);
    expect(ids(s.joiningNextMonth)).toEqual(["joins-next-month"]);
  });

  it("puts a December joiner in November's next-month intake, not a January one", () => {
    const s2 = summariseInternMonth([
      intern("dec-31", "2026-12-31", "2027-06-30"),
      intern("jan-1", "2027-01-01", "2027-07-01"),
    ], new Date(2026, 10, 30));
    expect(ids(s2.joiningNextMonth)).toEqual(["dec-31"]);
  });

  it("keeps the sheet's arithmetic for interns with end dates", () => {
    const dated = s.joiningThisMonth.filter((i) => i.endDate).length;
    expect(s.accumulated.length).toBe(s.fromPreviousMonth.length + dated);
    expect(s.proceeding.length).toBe(s.accumulated.length - s.leavingThisMonth.length);
  });

  it("handles January (previous month in the prior year)", () => {
    const jan = summariseInternMonth([intern("dec-joiner", "2026-12-15", "2027-03-01")], new Date(2027, 0, 5));
    expect(ids(jan.fromPreviousMonth)).toEqual(["dec-joiner"]);
  });
});
