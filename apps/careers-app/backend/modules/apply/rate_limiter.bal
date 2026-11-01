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

import ballerina/crypto;
import ballerina/lang.array;
import ballerina/time;

# How many requests one signed-in user may make within the signed-in window.
public configurable int signedInMaxPerUser = 60;

# The length of the signed-in window, in seconds.
public configurable int signedInWindowSeconds = 60;

const MAX_TRACKED_KEYS = 10000;

const SWEEP_INTERVAL_SECONDS = 60;

isolated function recentAttempts(int[] attempts, int windowStart) returns int[] {
    int[] recent = [];
    foreach int attempt in attempts {
        if attempt > windowStart {
            recent.push(attempt);
        }
    }
    return recent;
}

# The key a subject is counted under. It is hashed, so no personal data is held in memory.
public isolated function limiterKey(string kind, string value) returns string {
    byte[] digest = crypto:hashSha256(value.toBytes());
    return kind + ":" + array:toBase16(digest);
}

# Sliding-window limiter for the requests of signed-in users.
public isolated class UserRateLimiter {
    private map<int[]> attempts = {};
    private int lastSweep = 0;

    # Records a request from the signed-in user; false when they have used their allowance within the signed-in window.
    public isolated function tryAcquireUser(string subject) returns boolean =>
        self.tryAcquire(limiterKey("sub", subject), signedInMaxPerUser, signedInWindowSeconds);

    isolated function tryAcquire(string key, int maxAttempts, int windowSeconds) returns boolean {
        int now = time:utcNow()[0];
        int windowStart = now - windowSeconds;
        lock {
            if self.attempts.length() > MAX_TRACKED_KEYS && now - self.lastSweep >= SWEEP_INTERVAL_SECONDS {
                self.lastSweep = now;
                self.sweep(windowStart);
            }
            int[] recent = recentAttempts(self.attempts[key] ?: [], windowStart);
            if recent.length() >= maxAttempts {
                self.attempts[key] = recent;
                return false;
            }
            recent.push(now);
            self.attempts[key] = recent;
            return true;
        }
    }

    // Drops keys whose attempts have all aged out, so the map cannot grow without bound.
    private isolated function sweep(int windowStart) {
        lock {
            foreach string key in self.attempts.keys() {
                int[] recent = recentAttempts(self.attempts.get(key), windowStart);
                if recent.length() == 0 {
                    _ = self.attempts.remove(key);
                } else {
                    self.attempts[key] = recent;
                }
            }
        }
    }
}
