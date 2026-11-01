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

import { Box, Button, Stack, Typography } from "@mui/material";
import { ArrowRight } from "lucide-react";

interface JobAtAGlanceProps {
  team: string;
  officeLabel: string;
  jobType: string;
  onSeeAllRoles: () => void;
}

const JobAtAGlance = ({ team, officeLabel, jobType, onSeeAllRoles }: JobAtAGlanceProps) => (
  <Box
    sx={{
      borderRadius: "16px",
      // Size of the vacancy info card on wso2.com.
      p: "28px 32px",
      width: "100%",
      maxWidth: "387px",
      ml: { md: "auto" },
      backgroundColor: "#0F1B33",
      backgroundImage: [
        "radial-gradient(circle at 100% 100%, rgba(255,115,0,0.2), transparent 55%)",
        "linear-gradient(135deg, #0B1B3A 0%, #16295A 60%, #1B2547 100%)",
      ].join(", "),
      border: "1px solid rgba(255,255,255,0.12)",
      boxShadow: "0 18px 40px -16px rgba(11,18,32,0.5)",
    }}
  >
    <Typography sx={{ color: "#fff", fontSize: "12px", fontWeight: 700, letterSpacing: "0.1em", mb: 2 }}>
      AT A GLANCE
    </Typography>
    <Stack gap={0}>
      {[
        { label: "TEAM", value: team },
        { label: "OFFICE", value: officeLabel },
        { label: "TYPE", value: jobType },
      ].map((row, i) => (
        <Stack
          key={row.label}
          direction="row"
          justifyContent="space-between"
          alignItems="center"
          sx={{
            py: 1.5,
            borderTop: i > 0 ? "1px solid rgba(255,255,255,0.3)" : "none",
          }}
        >
          <Typography sx={{ color: "#fff", fontSize: "13px", fontWeight: 700, letterSpacing: "0.05em" }}>
            {row.label}
          </Typography>
          <Typography sx={{ color: "#fff", fontWeight: 600, fontSize: "15px" }}>{row.value}</Typography>
        </Stack>
      ))}
    </Stack>
    <Button
      variant="text"
      onClick={onSeeAllRoles}
      endIcon={<ArrowRight size={15} />}
      sx={{ mt: 2, color: "#fff", fontWeight: 700, px: 0, "& .MuiButton-endIcon": { color: "primary.main" } }}
    >
      See all open roles
    </Button>
  </Box>
);

export default JobAtAGlance;
