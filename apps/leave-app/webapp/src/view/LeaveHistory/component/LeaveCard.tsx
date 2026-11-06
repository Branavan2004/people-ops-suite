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

import DeleteIcon from "@mui/icons-material/Delete";
import DownloadIcon from "@mui/icons-material/Download";
import {
  Box,
  Button,
  Card,
  CardContent,
  Chip,
  IconButton,
  Stack,
  Tooltip,
  Typography,
  useTheme,
} from "@mui/material";

import { useConfirmationModalContext } from "@root/src/context/DialogContext";
import { ConfirmationType, LeaveType, Status } from "@root/src/types/types";
import { canCancelLeave, canDownloadSickNote, leaveTypeLabel } from "@root/src/utils/leaveRules";

const STATUS_LABELS: Record<Status, string> = {
  [Status.PENDING]: "Pending",
  [Status.APPROVED]: "Approved",
  [Status.REJECTED]: "Rejected",
  [Status.CANCELLED]: "Cancelled",
};

const STATUS_COLORS: Record<Status, "warning" | "success" | "error" | "default"> = {
  [Status.PENDING]: "warning",
  [Status.APPROVED]: "success",
  [Status.REJECTED]: "error",
  [Status.CANCELLED]: "default",
};

export interface LeaveCardProps {
  id: number;
  type: string;
  status: Status;
  rejectionReason: string | null;
  hasSickNote: boolean;
  sickNoteDeletedOn: string | null;
  startDate: string;
  endDate: string;
  duration: string;
  month: string;
  day: string;
  cancelling: boolean;
  onDelete?: (id: number) => void;
  onDownloadSickNote?: (id: number) => void;
}

export default function LeaveCard({
  id,
  duration,
  type,
  status,
  rejectionReason,
  hasSickNote,
  sickNoteDeletedOn,
  startDate,
  endDate,
  month,
  day,
  cancelling,
  onDelete,
  onDownloadSickNote,
}: LeaveCardProps) {
  const theme = useTheme();
  const { showConfirmation } = useConfirmationModalContext();

  const handleDelete = () => {
    showConfirmation(
      "Do you want to cancel this leave?",
      `This will cancel your ${formattedLabel} (${startDate} – ${endDate}). This action cannot be undone.`,
      ConfirmationType.accept,
      () => onDelete?.(id),
      "Yes, Cancel",
      "No, Keep It",
    );
  };

  const formattedLabel = leaveTypeLabel(type);
  const cancellable = canCancelLeave(status, startDate, new Date());
  const isSick = type === LeaveType.SICK;

  return (
    <Card
      sx={{
        borderRadius: "12px",
        border: `1px solid ${theme.palette.divider}`,
        alignItems: "center",
        boxShadow: "0 2px 8px rgba(5, 5, 5, 0.08)",
        height: "fit-content",
        "&:hover": {
          boxShadow: "0 4px 16px rgba(0, 0, 0, 0.12)",
          transform: "translateY(-2px)",
          transition: "all 0.2s ease",
        },
      }}
    >
      <CardContent sx={{ p: "1.25rem" }}>
        <Stack direction="row" spacing="1rem" alignItems="center">
          <Stack spacing="1rem" flex={1}>
            <Stack direction="row" justifyContent="space-between">
              <Typography
                variant="body2"
                sx={{
                  color: theme.palette.text.primary,
                  fontWeight: 600,
                }}
              >
                {formattedLabel}
              </Typography>
              <Stack direction="row" alignItems="center" gap="0.5rem">
                <Chip
                  size="small"
                  label={STATUS_LABELS[status]}
                  color={STATUS_COLORS[status]}
                  variant="outlined"
                />
                {cancellable && (
                  <Tooltip title="Cancel" arrow>
                    <span>
                      <IconButton
                        size="small"
                        aria-label="Cancel leave"
                        onClick={handleDelete}
                        disabled={cancelling}
                        sx={{
                          width: "32px",
                          height: "32px",
                          borderRadius: "4px",
                          backgroundColor: "transparent",
                          color: theme.palette.primary.main,
                          "&.Mui-disabled": {
                            color: theme.palette.text.disabled,
                          },
                          "&:hover": {
                            backgroundColor: "transparent",
                          },
                        }}
                      >
                        <DeleteIcon fontSize="medium" />
                      </IconButton>
                    </span>
                  </Tooltip>
                )}
              </Stack>
            </Stack>

            <Stack direction="row" gap="1rem" alignItems="center">
              {/* Mini Calendar */}
              <Box
                sx={{
                  width: "60px",
                  height: "60px",
                  borderRadius: "8px",
                  border: `2px solid ${theme.palette.primary.main}`,
                  display: "flex",
                  flexDirection: "column",
                  overflow: "hidden",
                  flexShrink: 0,
                }}
              >
                {/* Month header */}
                <Box
                  sx={{
                    borderBottom: `2px solid ${theme.palette.primary.main}`,
                    color: theme.palette.text.primary,
                    textAlign: "center",
                    py: "2px",
                    flex: "0 0 auto",
                  }}
                >
                  <Typography
                    variant="overline"
                    sx={{
                      fontWeight: 600,
                      textTransform: "uppercase",
                      letterSpacing: "0.5px",
                    }}
                  >
                    {month}
                  </Typography>
                </Box>

                {/* Date */}
                <Box
                  sx={{
                    backgroundColor: theme.palette.background.paper,
                    display: "flex",
                    alignItems: "center",
                    justifyContent: "center",
                    flex: 1,
                  }}
                >
                  <Typography
                    variant="h5"
                    sx={{
                      color: theme.palette.text.primary,
                      fontWeight: 700,
                      lineHeight: 1,
                    }}
                  >
                    {day}
                  </Typography>
                </Box>
              </Box>

              {/* Leave Details */}
              <Stack spacing="4px" flex={1}>
                <Typography
                  variant="body2"
                  sx={{
                    color: theme.palette.text.primary,
                    fontWeight: 500,
                  }}
                >
                  {startDate} - {endDate}
                </Typography>
                <Typography
                  variant="caption"
                  sx={{
                    color: theme.palette.text.secondary,
                  }}
                >
                  {duration}
                </Typography>
              </Stack>
            </Stack>

            {status === Status.REJECTED && rejectionReason && (
              <Typography variant="body2" sx={{ color: theme.palette.text.secondary }}>
                Reason: {rejectionReason}
              </Typography>
            )}

            {isSick && canDownloadSickNote(hasSickNote, sickNoteDeletedOn) && (
              <Box>
                <Button
                  size="small"
                  variant="outlined"
                  startIcon={<DownloadIcon />}
                  onClick={() => onDownloadSickNote?.(id)}
                >
                  Download sick note
                </Button>
              </Box>
            )}
            {sickNoteDeletedOn && (
              <Typography variant="caption" sx={{ color: theme.palette.text.secondary }}>
                Sick note deleted on {sickNoteDeletedOn.substring(0, 10)}
              </Typography>
            )}
          </Stack>
        </Stack>
      </CardContent>

    </Card>
  );
}
