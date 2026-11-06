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

import { Box, Dialog, DialogActions, DialogContent, Typography } from "@wso2/oxygen-ui";

import { BRAND_ORANGE, BRAND_TINT } from "@config/brand";

const TONES = {
  success: { color: "#10B981", background: "rgba(16,185,129,0.15)" },
  brand: { color: BRAND_ORANGE, background: BRAND_TINT.soft },
};

interface StatusDialogProps {
  open: boolean;
  onClose: () => void;
  tone: keyof typeof TONES;
  icon: React.ReactNode;
  title: string;
  children: React.ReactNode;
  actions: React.ReactNode;
}

// A centered confirmation pop-up: a round icon badge, a title, some text and a row of buttons.
const StatusDialog = ({ open, onClose, tone, icon, title, children, actions }: StatusDialogProps) => (
  <Dialog
    open={open}
    onClose={onClose}
    fullWidth
    maxWidth="xs"
    PaperProps={{ sx: { borderRadius: "16px", textAlign: "center" } }}
  >
    <DialogContent sx={{ pt: 4, pb: 1 }}>
      <Box
        sx={{
          width: 64,
          height: 64,
          mx: "auto",
          mb: 2,
          borderRadius: "50%",
          display: "flex",
          alignItems: "center",
          justifyContent: "center",
          backgroundColor: TONES[tone].background,
          color: TONES[tone].color,
        }}
      >
        {icon}
      </Box>
      <Typography fontWeight={800} fontSize="1.4rem" color="text.primary" mb={1}>
        {title}
      </Typography>
      {children}
    </DialogContent>
    <DialogActions sx={{ justifyContent: "center", gap: 1, pb: 3, pt: 2 }}>{actions}</DialogActions>
  </Dialog>
);

export default StatusDialog;
