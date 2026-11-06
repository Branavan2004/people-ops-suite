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

import { Box, Chip, useTheme } from "@mui/material";
import { DataGrid, GridColDef } from "@mui/x-data-grid";

import { SingleLeaveHistory } from "@root/src/types/types";
import { leaveTypeLabel } from "@root/src/utils/leaveRules";

export default function ApprovalHistoryTable({ rows }: { rows: SingleLeaveHistory[] }) {
  const theme = useTheme();

  const columns: GridColDef[] = [
    {
      field: "email",
      headerName: "Employee",
      type: "string",
      flex: 1,
      editable: false,
    },
    {
      field: "leaveType",
      headerName: "Leave type",
      type: "string",
      flex: 1,
      editable: false,
      valueGetter: (value) => (value ? leaveTypeLabel(String(value)) : ""),
    },
    {
      field: "startDate",
      headerName: "Start Date",
      type: "string",
      flex: 1,
      editable: false,
      renderCell: (params) => <span>{String(params.row?.startDate ?? "").substring(0, 10)}</span>,
    },
    {
      field: "endDate",
      headerName: "End Date",
      type: "string",
      flex: 1,
      editable: false,
      renderCell: (params) => <span>{String(params.row?.endDate ?? "").substring(0, 10)}</span>,
    },
    {
      field: "numberOfDays",
      headerName: "Day Count",
      type: "string",
      flex: 1,
      editable: false,
    },
    {
      field: "approverEmail",
      headerName: "Lead",
      type: "string",
      flex: 1,
      editable: false,
      valueGetter: (value) => value ?? "N/A",
    },
    {
      field: "status",
      headerName: "Status",
      type: "string",
      flex: 1,
      editable: false,
      align: "center",
      headerAlign: "center",
      renderCell: (params) => {
        const status = params.value?.toLowerCase() || "";
        const displayValue = params.value || "Unknown";

        let chipProps;
        switch (status) {
          case "approved":
            chipProps = {
              color: theme.palette.success.main,
              borderColor: theme.palette.success.main,
            };
            break;
          case "rejected":
            chipProps = {
              color: theme.palette.error.main,
              borderColor: theme.palette.error.main,
            };
            break;
          case "pending":
            chipProps = {
              color: theme.palette.primary.main,
              borderColor: theme.palette.primary.main,
            };
            break;
          case "cancelled":
            chipProps = {
              color: theme.palette.secondary.main,
              borderColor: theme.palette.secondary.main,
            };
            break;
          default:
            chipProps = {
              color: theme.palette.info.main,
              borderColor: theme.palette.info.main,
            };
        }

        return (
          <Chip
            label={displayValue}
            sx={{
              color: chipProps.borderColor,
              borderColor: chipProps.borderColor,
              backgroundColor: "transparent",
              borderRadius: "2rem",
              fontSize: theme.typography.caption.fontSize,
              fontWeight: 700,
              width: "10rem",
              textTransform: "capitalize",
              border: `0.1rem solid ${chipProps.color}`,
            }}
          />
        );
      },
    },
    {
      field: "rejectionReason",
      headerName: "Reason",
      type: "string",
      flex: 1.5,
      editable: false,
      valueGetter: (value) => value ?? "",
    },
  ];

  return (
    <Box sx={{ width: "100%" }}>
      <DataGrid
        rows={rows}
        columns={columns}
        initialState={{ pagination: { paginationModel: { pageSize: 10 } } }}
        pageSizeOptions={[10]}
        disableRowSelectionOnClick
        showToolbar
        slotProps={{
          columnsPanel: {
            sx: {
              "& .MuiTypography-root": {
                color: theme.palette.text.primary,
              },
            },
          },
        }}
      />
    </Box>
  );
}
