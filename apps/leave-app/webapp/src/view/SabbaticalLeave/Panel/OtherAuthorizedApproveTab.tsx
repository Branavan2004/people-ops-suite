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

import { CircularProgress, Stack, useTheme } from "@mui/material";

import { useCallback, useEffect } from "react";

import Title from "@root/src/component/common/Title";
import { PAGE_MAX_WIDTH } from "@root/src/config/ui";
import {
  fetchLeaveHistory,
  selectLeaveState,
  selectLeaves,
} from "@root/src/slices/leaveSlice/leave";
import { useAppDispatch, useAppSelector } from "@root/src/slices/store";
import { LeaveType, OrderBy, State, Status } from "@root/src/types/types";

import ApproveLeaveTable from "../component/ApproveLeaveTable";

export default function OtherAuthorizedApproveTab() {
  const theme = useTheme();
  const dispatch = useAppDispatch();
  const leaveState = useAppSelector(selectLeaveState);
  const leaves = useAppSelector(selectLeaves);
  const loading = leaveState === State.loading;

  const handleRefresh = useCallback(() => {
    dispatch(
      fetchLeaveHistory({
        subordinatesLeaves: true,
        leaveCategory: [LeaveType.OTHER_AUTHORIZED],
        statuses: [Status.PENDING],
        orderBy: OrderBy.DESC,
      }),
    );
  }, [dispatch]);

  useEffect(() => {
    handleRefresh();
  }, [handleRefresh]);

  return (
    <Stack gap="2rem" flexDirection="column" maxWidth={PAGE_MAX_WIDTH} mx="auto">
      <Stack
        direction="row"
        justifyContent="space-between"
        alignItems="center"
        borderBottom={`1px solid ${theme.palette.divider}`}
        pb="1rem"
      >
        <Title firstWord="Other Authorized" secondWord=" Leave Approval" borderEnabled={false} />
      </Stack>
      {loading ? (
        <Stack alignItems="center" justifyContent="center" minHeight="200px">
          <CircularProgress size={30} />
        </Stack>
      ) : (
        <ApproveLeaveTable
          rows={leaves}
          onRefresh={handleRefresh}
          requireRejectionReason
          showWaitingSince
          showComment
        />
      )}
    </Stack>
  );
}
