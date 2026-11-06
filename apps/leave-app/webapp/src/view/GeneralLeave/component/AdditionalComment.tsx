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
import ChatBubbleOutlineRoundedIcon from "@mui/icons-material/ChatBubbleOutlineRounded";
import { FormControlLabel, Stack, Switch, TextField, Typography, useTheme } from "@mui/material";

interface AdditionalCommentProps {
  comment: string;
  onCommentChange: (comment: string) => void;
  isPublicComment: boolean;
  onPublicCommentChange: (isPublic: boolean) => void;
  /** The leave type needs a reason for the lead: the comment is required and can't be made public. */
  reasonRequired?: boolean;
}

export default function AdditionalComment({
  comment,
  onCommentChange,
  isPublicComment,
  onPublicCommentChange,
  reasonRequired = false,
}: AdditionalCommentProps) {
  const theme = useTheme();

  return (
    <Stack gap={2}>
      <Stack direction="row" alignItems="center" gap={1}>
        <ChatBubbleOutlineRoundedIcon sx={{ fontSize: 20, color: theme.palette.primary.main }} />
        <Typography variant="h6" sx={{ color: theme.palette.customText.primary.p1.active }}>
          {reasonRequired ? "Reason" : "Additional Comments"}
        </Typography>
      </Stack>
      <TextField
        placeholder={
          reasonRequired
            ? "Tell your lead why you need this leave (required)..."
            : "Add a comment (optional)..."
        }
        required={reasonRequired}
        multiline
        minRows={3}
        fullWidth
        variant="outlined"
        size="small"
        value={comment}
        onChange={(e) => onCommentChange(e.target.value)}
      />
      {!reasonRequired && (
        <FormControlLabel
          control={
            <Switch
              checked={isPublicComment}
              onChange={(e) => onPublicCommentChange(e.target.checked)}
              size="small"
            />
          }
          label={
            <Typography variant="body2" sx={{ color: theme.palette.customText.primary.p3.active }}>
              Public comment
            </Typography>
          }
        />
      )}
    </Stack>
  );
}
