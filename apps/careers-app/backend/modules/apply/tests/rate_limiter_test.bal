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
function limiterKeysDoNotContainTheirValue() {
    string key = limiterKey("sub", "user-a");
    test:assertFalse(key.includes("user-a"));
    test:assertEquals(key, limiterKey("sub", "user-a"));
    test:assertNotEquals(key, limiterKey("sub", "user-b"));
}

@test:Config {}
function attemptsOutsideTheWindowAreForgotten() {
    test:assertEquals(recentAttempts([10, 50, 90, 120], 60), [90, 120]);
    test:assertEquals(recentAttempts([], 60), []);
}

@test:Config {}
function eachSignedInUserHasTheirOwnAllowance() {
    UserRateLimiter limiter = new;
    foreach int attempt in 1 ... signedInMaxPerUser {
        test:assertTrue(limiter.tryAcquireUser("user-a"), string `Request ${attempt} should be allowed`);
    }
    test:assertFalse(limiter.tryAcquireUser("user-a"));
    test:assertTrue(limiter.tryAcquireUser("user-b"));
}
