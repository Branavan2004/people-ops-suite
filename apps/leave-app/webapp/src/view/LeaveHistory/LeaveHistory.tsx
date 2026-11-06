// Copyright (c) 2025 WSO2 LLC. (https://www.wso2.com).
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

import { Box, CircularProgress, Stack, MenuItem, Select, SelectChangeEvent, Typography, useTheme } from "@mui/material";

import { useEffect, useMemo, useState } from "react";

import Title from "@root/src/component/common/Title";
import { PAGE_MAX_WIDTH } from "@root/src/config/ui";
import { downloadSickNote } from "@root/src/services/leaveService";
import { enqueueSnackbarMessage } from "@root/src/slices/commonSlice/common";
import {
  cancelLeave,
  fetchLeaveHistory,
  selectCancellingLeaveId,
  selectLeaveState,
  selectLeaves,
} from "@root/src/slices/leaveSlice/leave";
import { useAppDispatch, useAppSelector } from "@root/src/slices/store";
import { selectUser } from "@root/src/slices/userSlice/user";
import { LeaveType, OrderBy, State } from "@root/src/types/types";
import { HISTORY_STATUSES } from "@root/src/utils/leaveRules";
import { saveSickNoteBlob, sickNoteErrorMessage } from "@root/src/utils/sickNoteDownload";

import LeaveCard from "./component/LeaveCard";

interface LeaveHistoryProps {
  leaveType?: LeaveType[];
  title?: { firstWord: string; secondWord: string };
}

export default function LeaveHistory({ leaveType, title }: LeaveHistoryProps = {}) {
  const dispatch = useAppDispatch();
  const [currentYear] = useState<number>(new Date().getFullYear());
  const [selectedYear, setSelectedYear] = useState<number>(currentYear);
  const userInfo = useAppSelector(selectUser);
  const leaveState = useAppSelector(selectLeaveState);
  const leaves = useAppSelector(selectLeaves);
  const cancellingLeaveId = useAppSelector(selectCancellingLeaveId);
  const loading = leaveState === State.loading;
  const theme = useTheme();

  const availableYears = useMemo(() => {
    const parsedEmploymentStartYear = userInfo?.employmentStartDate
      ? new Date(userInfo.employmentStartDate).getFullYear()
      : currentYear;
    const employmentStartYear = Number.isNaN(parsedEmploymentStartYear)
      ? currentYear
      : parsedEmploymentStartYear;
    return Array.from(
      { length: currentYear - employmentStartYear + 1 },
      (_, i) => currentYear - i,
    );
  }, [userInfo?.employmentStartDate, currentYear]);

  useEffect(() => {
    if (userInfo?.workEmail) {
      dispatch(
        fetchLeaveHistory({
          email: userInfo.workEmail,
          startDate: `${selectedYear}-01-01`,
          endDate: `${selectedYear}-12-31`,
          statuses: HISTORY_STATUSES,
          orderBy: OrderBy.DESC,
          leaveCategory: leaveType,
        }),
      );
    }
  }, [dispatch, selectedYear, userInfo?.workEmail, leaveType]);

  const getMonthAndDay = (dateString: string) => {
    const date = new Date(dateString);
    const month = date.toLocaleString("en-US", { month: "short" }).toUpperCase();
    const day = date.getDate().toString();
    return { month, day };
  };

  const handleDeleteLeave = async (id: number) => {
    dispatch(cancelLeave(id));
  };

  const handleDownloadSickNote = async (id: number) => {
    try {
      saveSickNoteBlob(await downloadSickNote(id), id);
    } catch (err) {
      dispatch(enqueueSnackbarMessage({ message: await sickNoteErrorMessage(err), type: "error" }));
    }
  };

  const handleYearChange = (event: SelectChangeEvent<number>) => {
    setSelectedYear(Number(event.target.value));
  };

  return (
    <Stack maxWidth={PAGE_MAX_WIDTH} margin="auto" gap="1.5rem">
      <Stack direction="row" alignItems="center" justifyContent="space-between">
        <Title
          firstWord={title?.firstWord ?? "Leave"}
          secondWord={title?.secondWord ?? "History"}
        />
        <Select
          value={selectedYear}
          inputProps={{ "aria-label": "Leave history year" }}
          onChange={handleYearChange}
          size="small"
          sx={{
            color: theme.palette.text.primary,
            "& .MuiOutlinedInput-notchedOutline": {
              borderColor: theme.palette.divider,
            },
            "&:hover .MuiOutlinedInput-notchedOutline": {
              borderColor: theme.palette.text.secondary,
            },
            "&.Mui-focused .MuiOutlinedInput-notchedOutline": {
              borderColor: theme.palette.primary.main,
            },
            "& .MuiSelect-icon": {
              color: theme.palette.text.secondary,
            },
            minWidth: 100,
          }}
        >
          {availableYears.map((year) => (
            <MenuItem key={year} value={year}>
              {year}
            </MenuItem>
          ))}
        </Select>
      </Stack>
      <Box
        gap="2rem"
        display="grid"
        gridTemplateColumns={{ xs: "1fr", sm: "1fr 1fr", md: "1fr 1fr 1fr" }}
        minHeight="200px"
      >
        {loading && (
          <Box
            display="flex"
            justifyContent="center"
            alignItems="center"
            width="100%"
            gridColumn="1 / -1"
            minHeight="200px"
          >
            <CircularProgress size={30} />
          </Box>
        )}
        {!loading && leaves.length === 0 && (
          <Typography color={theme.palette.text.primary}>
            No leave history available for {selectedYear}.
          </Typography>
        )}
        {!loading &&
          leaves.map((leave) => {
            const { month, day } = getMonthAndDay(leave.startDate);
            return (
              <LeaveCard
                key={leave.id}
                id={leave.id}
                type={leave.leaveType}
                status={leave.status}
                rejectionReason={leave.rejectionReason}
                hasSickNote={leave.hasSickNote}
                sickNoteDeletedOn={leave.sickNoteDeletedOn}
                startDate={leave.startDate.substring(0, 10)}
                endDate={leave.endDate.substring(0, 10)}
                duration={`${leave.numberOfDays} days`}
                month={month}
                day={day}
                cancelling={cancellingLeaveId === leave.id}
                onDelete={handleDeleteLeave}
                onDownloadSickNote={handleDownloadSickNote}
              />
            );
          })}
      </Box>
    </Stack>
  );
}
