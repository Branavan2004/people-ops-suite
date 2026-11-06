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

import ballerina/test;

@test:Config {}
function franceOnlyTypesAreRefusedElsewhere() {
    test:assertTrue(checkLeaveTypeAllowed("compassionate", "France") is ());
    test:assertTrue(checkLeaveTypeAllowed("other_authorized", "France") is ());
    test:assertTrue(checkLeaveTypeAllowed("compassionate", "Sri Lanka") is error);
    test:assertTrue(checkLeaveTypeAllowed("other_authorized", ()) is error);
    test:assertTrue(checkLeaveTypeAllowed("casual", "Sri Lanka") is ());
}

@test:Config {}
function onlyOtherAuthorizedNeedsTheLead() {
    test:assertTrue(needsLeadApproval("other_authorized"));
    test:assertFalse(needsLeadApproval("compassionate"));
    test:assertFalse(needsLeadApproval("sabbatical")); // sabbatical keeps its own flow
}

@test:Config {}
function onlyOtherAuthorizedNeedsAReason() {
    test:assertTrue(checkCommentGiven("other_authorized", ()) is error);
    test:assertTrue(checkCommentGiven("other_authorized", "") is error);
    test:assertTrue(checkCommentGiven("other_authorized", "   ") is error);
    test:assertEquals(checkCommentGiven("other_authorized", "Jury service"), ());
    test:assertEquals(checkCommentGiven("compassionate", ()), ());
    test:assertEquals(checkCommentGiven("sick", ""), ());
}

@test:Config {}
function onlyFranceSickLeaveNeedsANote() {
    test:assertTrue(requiresSickNote("sick", "France"));
    test:assertFalse(requiresSickNote("sick", "Spain"));
    test:assertFalse(requiresSickNote("sick", ()));
    test:assertFalse(requiresSickNote("compassionate", "France"));
}

@test:Config {}
function pendingOtherAuthorizedBlocksOverlapsButPendingSabbaticalDoesNot() {
    test:assertTrue(isBlockingLeave("casual", "APPROVED"));
    test:assertTrue(isBlockingLeave("other_authorized", "PENDING"));
    test:assertFalse(isBlockingLeave("sabbatical", "PENDING"));
    test:assertFalse(isBlockingLeave("other_authorized", "REJECTED"));
    test:assertFalse(isBlockingLeave("casual", "CANCELLED"));
}

@test:Config {}
function onlyPendingRequestsCanBeDecided() {
    test:assertTrue(checkDecidable("PENDING") is ());
    foreach string status in ["APPROVED", "REJECTED", "CANCELLED"] {
        error? result = checkDecidable(status);
        test:assertTrue(result is error);
        test:assertEquals((<error>result).message(), "This request is no longer pending.");
    }
}

@test:Config {}
function rejectionReasonBounds() {
    test:assertTrue(normaliseRejectionReason(()) is error);
    test:assertTrue(normaliseRejectionReason("   ") is error);
    test:assertEquals(normaliseRejectionReason("  Overlaps the release week  "), "Overlaps the release week");
    string fiveHundred = repeatA(500);
    test:assertEquals(normaliseRejectionReason(fiveHundred), fiveHundred);
    string|error tooLong = normaliseRejectionReason(repeatA(501));
    test:assertTrue(tooLong is error);
    test:assertEquals((<error>tooLong).message(), "The reason can be at most 500 characters.");
}

isolated function repeatA(int count) returns string {
    string text = "";
    foreach int _ in 0 ..< count {
        text += "a";
    }
    return text;
}
