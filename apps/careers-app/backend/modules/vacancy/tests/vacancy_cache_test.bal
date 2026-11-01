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

import ballerina/http;
import ballerina/lang.runtime;
import ballerina/test;

// A fake upstream that counts its calls.
isolated class FakeUpstream {
    private int calls = 0;
    private final int status;
    private final int goodCalls;
    private final decimal delay;
    private final int statusAfter;

    // After `goodCalls` calls it fails: with a reply of `statusAfter` when that is set, otherwise with an error.
    isolated function init(int status = 200, int goodCalls = 1000, decimal delay = 0, int statusAfter = 0) {
        self.status = status;
        self.goodCalls = goodCalls;
        self.delay = delay;
        self.statusAfter = statusAfter;
    }

    isolated function call() returns http:Response|error {
        int number;
        lock {
            self.calls += 1;
            number = self.calls;
        }
        if self.delay > 0d {
            runtime:sleep(self.delay);
        }
        if number > self.goodCalls {
            if self.statusAfter == 0 {
                return error("upstream is down");
            }
            http:Response failed = new;
            failed.statusCode = self.statusAfter;
            return failed;
        }
        http:Response resp = new;
        resp.statusCode = self.status;
        resp.setJsonPayload({"id": 1});
        return resp;
    }

    isolated function count() returns int {
        lock {
            return self.calls;
        }
    }
}

function assertIsJob(json|http:Response|error result) {
    if result is json {
        test:assertEquals(result, {"id": 1});
    } else {
        test:assertFail("expected the cached JSON");
    }
}

function assertIsReplyWithStatus(json|http:Response|error result, int status) {
    if result is http:Response {
        test:assertEquals(result.statusCode, status);
    } else {
        test:assertFail("expected the upstream's reply");
    }
}

// Checks the condition every 50 ms until it holds or `timeout` seconds pass, and says whether it held. This replaces
// fixed pauses, which race the background refresh on a slow machine.
function waitFor(function () returns boolean condition, decimal timeout = 5) returns boolean {
    decimal waited = 0;
    while waited < timeout {
        if condition() {
            return true;
        }
        runtime:sleep(0.05d);
        waited += 0.05d;
    }
    return condition();
}

@test:Config {}
function secondRequestIsServedFromTheCache() {
    VacancyCache cache = new (600, 21600, 5);
    final FakeUpstream upstream = new;

    assertIsJob(cache.get("jobs", isolated function() returns http:Response|error => upstream.call()));
    assertIsJob(cache.get("jobs", isolated function() returns http:Response|error => upstream.call()));
    test:assertEquals(upstream.count(), 1);
}

@test:Config {}
function eachKeyIsCachedOnItsOwn() {
    VacancyCache cache = new (600, 21600, 5);
    final FakeUpstream upstream = new;

    assertIsJob(cache.get("job:1", isolated function() returns http:Response|error => upstream.call()));
    assertIsJob(cache.get("job:2", isolated function() returns http:Response|error => upstream.call()));
    test:assertEquals(upstream.count(), 2);
}

@test:Config {}
function failedRepliesAreNotCachedAsData() {
    VacancyCache cache = new (600, 21600, 0);
    final FakeUpstream upstream = new (500);

    json|http:Response|error first = cache.get("jobs", isolated function() returns http:Response|error => upstream.call());
    json|http:Response|error second = cache.get("jobs", isolated function() returns http:Response|error => upstream.call());
    assertIsReplyWithStatus(first, 500);
    assertIsReplyWithStatus(second, 500);
    test:assertEquals(upstream.count(), 2);
}

@test:Config {}
function unreachableUpstreamIsPassedBackAndNotCached() {
    VacancyCache cache = new (600, 21600, 0);
    final FakeUpstream upstream = new (200, 0);

    json|http:Response|error result = cache.get("jobs", isolated function() returns http:Response|error => upstream.call());
    test:assertTrue(result is error);
}

@test:Config {}
function simultaneousRequestsForAnEmptyKeyCallTheUpstreamOnce() {
    final VacancyCache cache = new (600, 21600, 5);
    final FakeUpstream upstream = new (200, 1000, 0.3);

    future<json|http:Response|error>[] requests = [];
    foreach int _ in 0 ..< 5 {
        future<json|http:Response|error> request =
            start cache.get("jobs", isolated function() returns http:Response|error => upstream.call());
        requests.push(request);
    }
    foreach future<json|http:Response|error> request in requests {
        json|http:Response|error result = wait request;
        assertIsJob(result);
    }
    test:assertEquals(upstream.count(), 1);
}

@test:Config {}
function aFailureIsRememberedBrieflyWithoutCallingTheUpstreamAgain() {
    VacancyCache cache = new (600, 21600, 5);
    final FakeUpstream upstream = new (503);

    assertIsReplyWithStatus(
        cache.get("jobs", isolated function() returns http:Response|error => upstream.call()), 503);
    assertIsReplyWithStatus(
        cache.get("jobs", isolated function() returns http:Response|error => upstream.call()), 503);
    test:assertEquals(upstream.count(), 1);
}

@test:Config {}
function aNotFoundIsRememberedAsANotFound() {
    VacancyCache cache = new (600, 21600, 5);
    final FakeUpstream upstream = new (404);

    assertIsReplyWithStatus(
        cache.get("job:999", isolated function() returns http:Response|error => upstream.call()), 404);
    assertIsReplyWithStatus(
        cache.get("job:999", isolated function() returns http:Response|error => upstream.call()), 404);
    test:assertEquals(upstream.count(), 1);
}

@test:Config {}
function repeatedFailuresAreRememberedForLonger() {
    VacancyCache cache = new (600, 21600, 1);
    final FakeUpstream upstream = new (500);

    // Failures are remembered for 1 second, then 2 seconds.
    json|http:Response|error first = cache.get("job:1", isolated function() returns http:Response|error => upstream.call());
    // Once the first failure is forgotten, the next request reaches the upstream again.
    json|http:Response|error second = first;
    test:assertTrue(waitFor(function() returns boolean {
        second = cache.get("job:1", isolated function() returns http:Response|error => upstream.call());
        return upstream.count() == 2;
    }), "the first failure should be forgotten after about a second");
    json|http:Response|error third = cache.get("job:1", isolated function() returns http:Response|error => upstream.call());
    assertIsReplyWithStatus(first, 500);
    assertIsReplyWithStatus(second, 500);
    assertIsReplyWithStatus(third, 500);
    test:assertEquals(upstream.count(), 2, "the third request should not reach the upstream");
}

@test:Config {}
function anUnreachableUpstreamIsRememberedBrieflyToo() {
    VacancyCache cache = new (600, 21600, 5);
    final FakeUpstream upstream = new (200, 0);

    json|http:Response|error first = cache.get("jobs", isolated function() returns http:Response|error => upstream.call());
    json|http:Response|error second = cache.get("jobs", isolated function() returns http:Response|error => upstream.call());
    test:assertTrue(first is error);
    test:assertTrue(second is error);
    test:assertEquals(upstream.count(), 1);
}

@test:Config {}
function oldCopyIsServedAtOnceWhileItRefreshesInTheBackground() {
    // A refresh time of 0 treats every copy as old.
    VacancyCache cache = new (0, 21600, 5);
    final FakeUpstream upstream = new;

    assertIsJob(cache.get("jobs", isolated function() returns http:Response|error => upstream.call()));
    assertIsJob(cache.get("jobs", isolated function() returns http:Response|error => upstream.call()));
    test:assertTrue(waitFor(function() returns boolean => upstream.count() == 2),
        "the second request should have started one refresh");
}

@test:Config {}
function failedRefreshKeepsTheCachedCopy() {
    VacancyCache cache = new (0, 21600, 5);
    // Only the first call succeeds.
    final FakeUpstream upstream = new (200, 1);

    assertIsJob(cache.get("jobs", isolated function() returns http:Response|error => upstream.call()));
    assertIsJob(cache.get("jobs", isolated function() returns http:Response|error => upstream.call()));
    test:assertTrue(waitFor(function() returns boolean => cache.recentFailure("jobs") is FailedLoad),
        "the refresh should have failed and been remembered");
    assertIsJob(cache.get("jobs", isolated function() returns http:Response|error => upstream.call()));
}

@test:Config {}
function theDefaultSettingsAreAccepted() {
    test:assertEquals(settingsProblem(600, 21600, 5), ());
}

@test:Config {}
function aRefreshTimeBelowOneSecondIsRejected() {
    string? problem = settingsProblem(0, 21600, 5);
    test:assertTrue(problem is string && problem.includes("refreshAfterSeconds"));
    test:assertTrue(settingsProblem(-5, 21600, 5) is string);
}

@test:Config {}
function aMaxStaleTimeNotAboveTheRefreshTimeIsRejected() {
    string? problem = settingsProblem(600, 600, 5);
    test:assertTrue(problem is string && problem.includes("maxStaleSeconds"));
    test:assertTrue(settingsProblem(600, 100, 5) is string);
}

@test:Config {}
function aFailFastTimeOutsideOneToSixtyIsRejected() {
    string? problem = settingsProblem(600, 21600, 0);
    test:assertTrue(problem is string && problem.includes("failFastSeconds"));
    test:assertTrue(settingsProblem(600, 21600, 61) is string);
    test:assertEquals(settingsProblem(600, 21600, 60), ());
}

// The cache is refreshed at once on each hit (refresh time 0); the first call fills it and the later ones fail.
function jobStatusAfterARefreshThatFails(string key, int statusAfter) returns json|http:Response|error {
    VacancyCache cache = new (0, 21600, 5);
    final FakeUpstream upstream = new (200, 1, 0d, statusAfter);

    assertIsJob(cache.get(key, isolated function() returns http:Response|error => upstream.call()));
    assertIsJob(cache.get(key, isolated function() returns http:Response|error => upstream.call()));
    // A failed refresh records its failure last, after dropping a job that is gone, so this means it has finished.
    test:assertTrue(waitFor(function() returns boolean => cache.recentFailure(key) is FailedLoad),
        "the refresh should have failed and been remembered");
    return cache.get(key, isolated function() returns http:Response|error => upstream.call());
}

@test:Config {}
function aLoadThatPanicsDoesNotLeaveTheKeyStuck() {
    // A failure is remembered for 1 second here.
    VacancyCache cache = new (600, 21600, 1);
    final FakeUpstream upstream = new;

    json|http:Response|error panicked = cache.get("jobs", isolated function() returns http:Response|error {
        panic error("the call panicked");
    });
    test:assertTrue(panicked is error, "a panic should come back as an error");

    // After the remembered failure expires, the key can be loaded again, so it was released.
    json|http:Response|error loaded = panicked;
    test:assertTrue(waitFor(function() returns boolean {
        loaded = cache.get("jobs", isolated function() returns http:Response|error => upstream.call());
        return loaded is json;
    }), "the key should load again once the remembered failure expires");
    assertIsJob(loaded);
    test:assertEquals(upstream.count(), 1);
}

@test:Config {}
function theFirstFailureOfAKeyCountsAsOne() {
    test:assertEquals(failureCount((), 1000, 5), 1);
}

@test:Config {}
function aFailureRightAfterTheBackoffEndsCountsAsAnotherInARow() {
    FailedLoad previous = {status: 404, failedAt: 1000, count: 1};
    test:assertEquals(failureCount(previous, 1006, 5), 2);
    FailedLoad third = {status: 404, failedAt: 1000, count: 3};
    test:assertEquals(failureCount(third, 1021, 5), 4);
}

@test:Config {}
function aFailureLongAfterThePreviousStartsAgainAtOne() {
    FailedLoad previous = {status: 404, failedAt: 1000, count: 1};
    test:assertEquals(failureCount(previous, 1010, 5), 1);
    FailedLoad many = {status: 404, failedAt: 1000, count: 7};
    test:assertEquals(failureCount(many, 1000 + 3 * 24 * 3600, 5), 1);
    test:assertEquals(failureCount(many, 1000 + 330, 5), 8);
}

@test:Config {}
function aFailedRefreshIsNotRepeatedOnEveryRequestWhileItIsRemembered() {
    VacancyCache cache = new (0, 21600, 5);
    // The first call fills the cache; every later call to the upstream fails.
    final FakeUpstream upstream = new (200, 1);

    assertIsJob(cache.get("jobs", isolated function() returns http:Response|error => upstream.call()));
    assertIsJob(cache.get("jobs", isolated function() returns http:Response|error => upstream.call()));
    test:assertTrue(waitFor(function() returns boolean => cache.recentFailure("jobs") is FailedLoad),
        "the first stale request should start one refresh, which fails and is remembered");
    test:assertEquals(upstream.count(), 2);

    foreach int _ in 0 ..< 5 {
        assertIsJob(cache.get("jobs", isolated function() returns http:Response|error => upstream.call()));
    }
    // There is nothing to wait for here, so give a refresh that wrongly started a moment to reach the upstream.
    runtime:sleep(0.3);
    test:assertEquals(upstream.count(), 2, "no new refresh while the failure is remembered");
}

@test:Config {}
function aJobThatARefreshFindsMissingIsNoLongerServed() {
    json|http:Response|error result = jobStatusAfterARefreshThatFails("job:7", 404);
    test:assertTrue(result is http:Response && result.statusCode == 404, "the closed job must not be served");
}

@test:Config {}
function aJobThatARefreshFindsUnpublishedIsNoLongerServed() {
    json|http:Response|error result = jobStatusAfterARefreshThatFails("job:7", 400);
    test:assertTrue(result is http:Response && result.statusCode == 400, "the unpublished job must not be served");
}

@test:Config {}
function aServerErrorOnARefreshStillKeepsTheJobCopy() {
    assertIsJob(jobStatusAfterARefreshThatFails("job:7", 500));
}

@test:Config {}
function aMissingReplyOnARefreshOfTheJobListKeepsTheListCopy() {
    assertIsJob(jobStatusAfterARefreshThatFails("jobs", 404));
}
