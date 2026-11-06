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

import { LeaveType } from "@root/src/types/types";

import LeaveHistory from "./LeaveHistory";

export default function GeneralLeaveHistory() {
  return (
    <LeaveHistory
      leaveType={[
        LeaveType.ANNUAL,
        LeaveType.CASUAL,
        LeaveType.CONGES_PAYES,
        LeaveType.RTT,
        LeaveType.SICK,
        LeaveType.LIEU,
        LeaveType.MATERNITY,
        LeaveType.PATERNITY,
        LeaveType.MEDICAL,
        LeaveType.NO_PAY,
        LeaveType.COMPASSIONATE,
        LeaveType.OTHER_AUTHORIZED,
      ]}
      title={{ firstWord: "General", secondWord: `Leave History` }}
    />
  );
}
