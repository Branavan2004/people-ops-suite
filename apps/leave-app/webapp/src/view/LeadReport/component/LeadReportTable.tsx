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

import CalendarMonthIcon from "@mui/icons-material/CalendarMonth";
import CalendarTodayIcon from "@mui/icons-material/CalendarToday";
import Brightness5Icon from "@mui/icons-material/Brightness5";
import { Chip, Stack, Typography, alpha, useTheme } from "@mui/material";
import Box from "@mui/material/Box";
import { DataGrid, GridColDef } from "@mui/x-data-grid";
import dayjs from "dayjs";

import { LeaveType, PeriodType, SingleLeaveHistory } from "@root/src/types/types";

const LEAVE_TYPE_CONFIG: Record<string, { label: string; color: string }> = {
  [LeaveType.CASUAL]: { label: "Casual", color: "#ff9800" },
  [LeaveType.ANNUAL]: { label: "Annual", color: "#3f51b5" },
  [LeaveType.SICK]: { label: "Sick", color: "#2196f3" },
  [LeaveType.SABBATICAL]: { label: "Sabbatical", color: "#9c27b0" },
  [LeaveType.MATERNITY]: { label: "Maternity", color: "#4caf50" },
  [LeaveType.PATERNITY]: { label: "Paternity", color: "#009688" },
  [LeaveType.LIEU]: { label: "Lieu", color: "#00bcd4" },
  [LeaveType.CONGES_PAYES]: { label: "Congés Payés", color: "#607d8b" },
  [LeaveType.RTT]: { label: "RTT", color: "#795548" },
  [LeaveType.MEDICAL]: { label: "Medical", color: "#e91e63" },
  [LeaveType.NO_PAY]: { label: "No-Pay", color: "#757575" },
  [LeaveType.COMPASSIONATE]: { label: "Compassionate", color: "#5c6bc0" },
  [LeaveType.OTHER_AUTHORIZED]: { label: "Other Authorized", color: "#8d6e63" },
};

const PERIOD_CONFIG: Record<string, { label: string; icon: React.ReactNode }> = {
  [PeriodType.ONE]: { label: "Full Day", icon: <CalendarTodayIcon sx={{ fontSize: 13 }} /> },
  [PeriodType.MULTIPLE]: { label: "Multiple Days", icon: <CalendarMonthIcon sx={{ fontSize: 13 }} /> },
  [PeriodType.HALF]: { label: "Half Day", icon: <Brightness5Icon sx={{ fontSize: 13 }} /> },
};

function formatDate(raw: string): string {
  const d = dayjs(raw.substring(0, 10));
  return d.isValid() ? d.format("MMM D, YYYY") : raw;
}

interface LeadReportTableProps {
  rows: SingleLeaveHistory[];
  loading: boolean;
}

export default function LeadReportTable({ rows, loading }: LeadReportTableProps) {
  const theme = useTheme();
  const totalDays = rows.reduce((sum, r) => sum + (r.numberOfDays ?? 0), 0);
  const uniqueEmails = new Set(rows.map((r) => r.email));
  const isMultipleEmployees = uniqueEmails.size > 1;

  const columns: GridColDef[] = [
    {
      field: "email",
      headerName: "Employee",
      flex: 1.5,
    },
    {
      field: "leaveType",
      headerName: "Leave Type",
      flex: 1,
      renderCell: (params) => {
        const key = String(params.value ?? "");
        const cfg = LEAVE_TYPE_CONFIG[key];
        const label = cfg?.label ?? key.replace(/_/g, " ").replace(/\b\w/g, (c) => c.toUpperCase());
        const color = cfg?.color ?? "#607d8b";
        return (
          <Chip
            label={label}
            size="small"
            sx={{
              bgcolor: alpha(color, 0.1),
              color,
              fontWeight: 600,
              fontSize: 11,
              height: 22,
              border: "none",
            }}
          />
        );
      },
    },
    {
      field: "startDate",
      headerName: "Start Date",
      flex: 1,
      renderCell: (params) => (
        <Stack height="100%" justifyContent="center">
          <Typography variant="body2">{formatDate(String(params.value ?? ""))}</Typography>
        </Stack>
      ),
    },
    {
      field: "endDate",
      headerName: "End Date",
      flex: 1,
      renderCell: (params) => (
        <Stack height="100%" justifyContent="center">
          <Typography variant="body2">{formatDate(String(params.value ?? ""))}</Typography>
        </Stack>
      ),
    },
    {
      field: "numberOfDays",
      headerName: "Days",
      flex: 0.6,
      renderCell: (params) => (
        <Stack height="100%" justifyContent="center">
          <Typography variant="body2" fontWeight={700}>{params.value}</Typography>
        </Stack>
      ),
    },
    {
      field: "periodType",
      headerName: "Period",
      flex: 1,
      renderCell: (params) => {
        const key = String(params.value ?? "");
        const cfg = PERIOD_CONFIG[key];
        return (
          <Stack direction="row" alignItems="center" gap={0.5} height="100%" color="text.secondary">
            {cfg?.icon}
            <Typography variant="caption">{cfg?.label ?? key}</Typography>
          </Stack>
        );
      },
    },
  ];

  return (
    <Box sx={{ width: "100%" }}>
      {!isMultipleEmployees && rows.length > 0 && (
        <Stack direction="row" justifyContent="flex-end" mb={1}>
          <Chip
            label={`Total: ${totalDays} day${totalDays !== 1 ? "s" : ""}`}
            size="small"
            color="primary"
          />
        </Stack>
      )}
      <DataGrid
        rows={rows}
        columns={columns}
        loading={loading}
        initialState={{ pagination: { paginationModel: { pageSize: 10 } } }}
        pageSizeOptions={[5, 10, 25]}
        disableRowSelectionOnClick
        showToolbar
        rowHeight={52}
        slotProps={{
          columnsPanel: {
            sx: {
              "& .MuiTypography-root": {
                color: theme.palette.text.primary,
              },
            },
          },
        }}
        sx={{
          "& .MuiDataGrid-columnHeader": {
            bgcolor:
              theme.palette.mode === "dark" ? "rgba(255,255,255,0.04)" : "rgba(0,0,0,0.03)",
          },
          "& .MuiDataGrid-row:hover": {
            bgcolor:
              theme.palette.mode === "dark" ? "rgba(255,255,255,0.03)" : "rgba(0,0,0,0.02)",
          },
        }}
      />
    </Box>
  );
}
