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

import {
  Button,
  Dialog,
  DialogActions,
  DialogContent,
  DialogContentText,
  DialogTitle,
  TextField,
} from "@mui/material";

import { useEffect, useState } from "react";

import { REJECTION_REASON_MAX, rejectionReasonProblem } from "@root/src/utils/leaveRules";

interface RejectReasonDialogProps {
  open: boolean;
  onCancel: () => void;
  onConfirm: (reason: string) => void;
}

export default function RejectReasonDialog({ open, onCancel, onConfirm }: RejectReasonDialogProps) {
  const [reason, setReason] = useState("");
  const [touched, setTouched] = useState(false);

  useEffect(() => {
    if (open) {
      setReason("");
      setTouched(false);
    }
  }, [open]);

  const problem = rejectionReasonProblem(reason);
  const showProblem = (touched || reason.length > REJECTION_REASON_MAX) && problem !== "";

  const handleConfirm = () => {
    if (problem) {
      setTouched(true);
      return;
    }
    onConfirm(reason.trim());
  };

  return (
    <Dialog
      open={open}
      onClose={onCancel}
      fullWidth
      maxWidth="sm"
      aria-labelledby="reject-reason-title"
    >
      <DialogTitle id="reject-reason-title">Reject this request?</DialogTitle>
      <DialogContent>
        <DialogContentText sx={{ mb: 2 }}>
          The employee will see this reason. It is required.
        </DialogContentText>
        <TextField
          autoFocus
          fullWidth
          multiline
          minRows={3}
          label="Reason for rejection"
          value={reason}
          onChange={(e) => setReason(e.target.value)}
          onBlur={() => setTouched(true)}
          error={showProblem}
          helperText={`${showProblem ? problem + " " : ""}${reason.trim().length}/${REJECTION_REASON_MAX}`}
        />
      </DialogContent>
      <DialogActions>
        <Button onClick={onCancel}>Cancel</Button>
        <Button onClick={handleConfirm} color="error" variant="contained" disabled={!!problem}>
          Reject
        </Button>
      </DialogActions>
    </Dialog>
  );
}
