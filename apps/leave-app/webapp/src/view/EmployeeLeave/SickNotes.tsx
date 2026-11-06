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

import DownloadIcon from "@mui/icons-material/Download";
import {
  Alert,
  Box,
  Button,
  CircularProgress,
  Paper,
  Stack,
  Table,
  TableBody,
  TableCell,
  TableContainer,
  TableHead,
  TableRow,
  TextField,
  Typography,
} from "@mui/material";
import { DatePicker } from "@mui/x-date-pickers";
import dayjs, { Dayjs } from "dayjs";
import axios, { HttpStatusCode } from "axios";
import { useEffect, useMemo, useState } from "react";

import Title from "@root/src/component/common/Title";
import { PAGE_MAX_WIDTH } from "@root/src/config/ui";
import { downloadSickNote, getSickNotes } from "@root/src/services/leaveService";
import { enqueueSnackbarMessage } from "@root/src/slices/commonSlice/common";
import { useAppDispatch } from "@root/src/slices/store";
import { SickNoteSummary } from "@root/src/types/types";
import { saveSickNoteBlob, sickNoteErrorMessage } from "@root/src/utils/sickNoteDownload";

const DATE_FORMAT = "YYYY-MM-DD";
const LOAD_ERROR = "Sick notes could not be loaded.";

const loadErrorMessage = (err: unknown): string => {
  if (axios.isAxiosError(err)) {
    if (err.response?.status === HttpStatusCode.Forbidden) return "You do not have permission to view sick notes.";
    const message = (err.response?.data as { message?: unknown } | undefined)?.message;
    if (typeof message === "string" && message) return message;
  }
  return LOAD_ERROR;
};

export default function SickNotes() {
  const dispatch = useAppDispatch();
  const [startDate, setStartDate] = useState<Dayjs | null>(dayjs().startOf("month"));
  const [endDate, setEndDate] = useState<Dayjs | null>(dayjs().endOf("month"));
  const [employeeFilter, setEmployeeFilter] = useState("");
  const [notes, setNotes] = useState<SickNoteSummary[]>([]);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [downloadingId, setDownloadingId] = useState<number | null>(null);

  const rangeValid = !!startDate?.isValid() && !!endDate?.isValid() && !endDate.isBefore(startDate, "day");

  useEffect(() => {
    if (!rangeValid || !startDate || !endDate) {
      setNotes([]);
      return;
    }
    let cancelled = false;
    setLoading(true);
    setError(null);
    getSickNotes(startDate.format(DATE_FORMAT), endDate.format(DATE_FORMAT))
      .then((result) => {
        if (!cancelled) setNotes(result);
      })
      .catch((err) => {
        if (!cancelled) {
          setNotes([]);
          setError(loadErrorMessage(err));
        }
      })
      .finally(() => {
        if (!cancelled) setLoading(false);
      });
    return () => {
      cancelled = true;
    };
  }, [startDate, endDate, rangeValid]);

  const filtered = useMemo(() => {
    const term = employeeFilter.trim().toLowerCase();
    return term ? notes.filter((n) => n.email.toLowerCase().includes(term)) : notes;
  }, [notes, employeeFilter]);

  const handleDownload = async (leaveId: number) => {
    setDownloadingId(leaveId);
    try {
      saveSickNoteBlob(await downloadSickNote(leaveId), leaveId);
    } catch (err) {
      dispatch(enqueueSnackbarMessage({ message: await sickNoteErrorMessage(err), type: "error" }));
    } finally {
      setDownloadingId(null);
    }
  };

  const formatDate = (value: string) => dayjs(value).format(DATE_FORMAT);

  return (
    <Stack gap="1.5rem" maxWidth={PAGE_MAX_WIDTH} mx="auto">
      <Title firstWord="Sick" secondWord="Notes" />

      <Stack direction={{ xs: "column", sm: "row" }} gap="1rem">
        <DatePicker
          label="From"
          value={startDate}
          onChange={setStartDate}
          format={DATE_FORMAT}
          sx={{ flex: 1 }}
          slotProps={{ textField: { size: "small", fullWidth: true } }}
        />
        <DatePicker
          label="To"
          value={endDate}
          onChange={setEndDate}
          format={DATE_FORMAT}
          minDate={startDate ?? undefined}
          sx={{ flex: 1 }}
          slotProps={{ textField: { size: "small", fullWidth: true } }}
        />
        <TextField
          label="Employee"
          placeholder="Filter by email"
          size="small"
          value={employeeFilter}
          onChange={(e) => setEmployeeFilter(e.target.value)}
          sx={{ flex: 1 }}
        />
      </Stack>

      {error && <Alert severity="error">{error}</Alert>}

      {loading ? (
        <Box display="flex" justifyContent="center" py={4}>
          <CircularProgress />
        </Box>
      ) : (
        <TableContainer component={Paper} variant="outlined">
          <Table size="small">
            <TableHead>
              <TableRow>
                <TableCell>Employee</TableCell>
                <TableCell>Dates</TableCell>
                <TableCell align="right">Days</TableCell>
                <TableCell>Status</TableCell>
                <TableCell>Uploaded</TableCell>
                <TableCell>Note</TableCell>
              </TableRow>
            </TableHead>
            <TableBody>
              {filtered.length === 0 ? (
                <TableRow>
                  <TableCell colSpan={6}>
                    <Typography variant="body2" color="text.secondary" textAlign="center">
                      {error ? "No data." : "No sick notes found for this period."}
                    </Typography>
                  </TableCell>
                </TableRow>
              ) : (
                filtered.map((n) => (
                  <TableRow key={n.leaveId} hover>
                    <TableCell>{n.email}</TableCell>
                    <TableCell>
                      {formatDate(n.startDate)} – {formatDate(n.endDate)}
                    </TableCell>
                    <TableCell align="right">{n.numberOfDays}</TableCell>
                    <TableCell>{n.status}</TableCell>
                    <TableCell>{formatDate(n.uploadedAt)}</TableCell>
                    <TableCell>
                      {n.deletedAt ? (
                        <Typography variant="body2" color="text.secondary">
                          Deleted on {formatDate(n.deletedAt)}
                        </Typography>
                      ) : (
                        <Button
                          size="small"
                          startIcon={<DownloadIcon />}
                          disabled={downloadingId === n.leaveId}
                          onClick={() => handleDownload(n.leaveId)}
                        >
                          Download
                        </Button>
                      )}
                    </TableCell>
                  </TableRow>
                ))
              )}
            </TableBody>
          </Table>
        </TableContainer>
      )}
    </Stack>
  );
}
