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

import leave_scheduler.email;

import ballerina/log;

# Entry point for the scheduled Leave App job runner (deployed as a WSO2 Choreo Scheduled Task, run daily).
# Runs every registered job in turn regardless of whether an earlier one failed, then reports an
# error if any job failed — so the Choreo run visibly shows as failed and can be noticed, without
# one job's failure preventing the others from running.
#
# + return - Error if the debug email configuration is invalid, or if any job reported a failure
public function main() returns error? {
    check email:validateDebugConfig();

    error? sabbaticalReminderResult = runSabbaticalReminder();
    if sabbaticalReminderResult is error {
        log:printError("Sabbatical reminder job failed", sabbaticalReminderResult);
    }
    // Future jobs are added here the same way: call the job's `run<JobName>()` function (defined in
    // functions.bal), log its error if any, and track it below — every job still runs even if an
    // earlier one failed.

    if sabbaticalReminderResult is error {
        return error("One or more scheduled jobs failed — see logs for details");
    }
}
