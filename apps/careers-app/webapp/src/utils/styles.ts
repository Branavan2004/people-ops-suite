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

// The fully rounded button used for primary actions across the app.
export const pillButtonSx = { borderRadius: "999px", fontWeight: 700 } as const;

// The thin border and rounded corners of a card.
export const cardSx = { border: "1px solid", borderColor: "divider", borderRadius: "8px" } as const;

// A grid cell that spans the whole row on a wide screen.
export const fullRowSx = { gridColumn: { md: "1 / -1" } } as const;
