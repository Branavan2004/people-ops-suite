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

import { parseDate } from "@utils/employeeHub/dateHelpers";

type DatedIntern = { joinedDate: string | null; endDate: string | null };

// The monthly intern count summary, defined the way HR's "Intern Count
// Summary" sheet defines it, for the month containing `selectedDate`:
//
//   fromPreviousMonth  joined before the 1st and still on the internship on the 1st
//   joiningThisMonth   joined during the month
//   accumulated        fromPreviousMonth + joiningThisMonth
//   leavingThisMonth   accumulated interns whose internship ends during the month
//   proceeding         accumulated interns whose internship continues past month end
//   joiningNextMonth   joining during the following month (the upcoming intake)
//
// so accumulated = fromPreviousMonth + joiningThisMonth and
// proceeding = accumulated - leavingThisMonth, as on the sheet. An intern with
// no end date cannot be placed in the month, so only joiningThisMonth counts them.
export interface InternMonthSummary<T> {
  fromPreviousMonth: T[];
  joiningThisMonth: T[];
  accumulated: T[];
  leavingThisMonth: T[];
  proceeding: T[];
  joiningNextMonth: T[];
}

export function summariseInternMonth<T extends DatedIntern>(interns: T[], selectedDate: Date): InternMonthSummary<T> {
  const monthStart = new Date(selectedDate.getFullYear(), selectedDate.getMonth(), 1);
  const monthEnd = new Date(selectedDate.getFullYear(), selectedDate.getMonth() + 1, 0);
  const nextMonthEnd = new Date(selectedDate.getFullYear(), selectedDate.getMonth() + 2, 0);

  const summary: InternMonthSummary<T> = {
    fromPreviousMonth: [],
    joiningThisMonth: [],
    accumulated: [],
    leavingThisMonth: [],
    proceeding: [],
    joiningNextMonth: [],
  };

  interns.forEach((intern) => {
    const joined = parseDate(intern.joinedDate);
    const end = parseDate(intern.endDate);
    if (!joined) return;

    if (joined > monthEnd && joined <= nextMonthEnd) summary.joiningNextMonth.push(intern);

    const joinsThisMonth = joined >= monthStart && joined <= monthEnd;
    if (joinsThisMonth) summary.joiningThisMonth.push(intern);
    if (!end) return;

    const carriedOver = joined < monthStart && end >= monthStart;
    if (carriedOver) summary.fromPreviousMonth.push(intern);
    if (!carriedOver && !joinsThisMonth) return;

    summary.accumulated.push(intern);
    if (end <= monthEnd) summary.leavingThisMonth.push(intern);
    else summary.proceeding.push(intern);
  });

  return summary;
}
