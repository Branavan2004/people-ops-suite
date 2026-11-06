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
import { SvgIconComponent } from "@mui/icons-material";
import AccessTimeIcon from "@mui/icons-material/AccessTime";
import BeachAccessIcon from "@mui/icons-material/BeachAccess";
import CategoryRoundedIcon from "@mui/icons-material/CategoryRounded";
import EventAvailableIcon from "@mui/icons-material/EventAvailable";
import FamilyRestroomIcon from "@mui/icons-material/FamilyRestroom";
import HandshakeOutlinedIcon from "@mui/icons-material/HandshakeOutlined";
import HeartBrokenOutlinedIcon from "@mui/icons-material/HeartBrokenOutlined";
import LocalHospitalIcon from "@mui/icons-material/LocalHospital";
import PregnantWomanIcon from "@mui/icons-material/PregnantWoman";
import ScheduleIcon from "@mui/icons-material/Schedule";
import TimerRoundedIcon from "@mui/icons-material/TimerRounded";
import WorkOffIcon from "@mui/icons-material/WorkOff";
import { Box, Stack, Tooltip, Typography, useTheme } from "@mui/material";

import { useEffect, useMemo } from "react";

import {
  DayPortion,
  DayPortionLabel,
  EmployeeLocation,
  LeaveLabel,
  LeaveTooltip,
  LeaveType,
} from "@root/src/types/types";

import DatePill from "./DatePill";
import LeaveSelectionIcon from "./LeaveSelectionIcon";

interface LeaveTypeOption {
  type: LeaveType;
  label: LeaveLabel;
  icon: SvgIconComponent;
  tooltip?: string;
  info?: string;
}

const COMMON_LEAVE_TYPES: LeaveTypeOption[] = [
  { type: LeaveType.MATERNITY, label: LeaveLabel.MATERNITY, icon: PregnantWomanIcon },
  { type: LeaveType.PATERNITY, label: LeaveLabel.PATERNITY, icon: FamilyRestroomIcon },
  { type: LeaveType.LIEU, label: LeaveLabel.LIEU, icon: AccessTimeIcon },
];

const LOCATION_LEAVE_TYPES: Record<string, LeaveTypeOption[]> = {
  [EmployeeLocation.LK]: [{ type: LeaveType.CASUAL, label: LeaveLabel.CASUAL, icon: WorkOffIcon }],
  [EmployeeLocation.IN]: [
    { type: LeaveType.ANNUAL, label: LeaveLabel.INDIA_ANNUAL, icon: EventAvailableIcon },
    {
      type: LeaveType.CASUAL,
      label: LeaveLabel.INDIA_CASUAL,
      icon: WorkOffIcon,
      info: "Maharashtra only",
    },
    {
      type: LeaveType.SICK,
      label: LeaveLabel.SICK,
      icon: LocalHospitalIcon,
      info: "Karnataka only",
    },
  ],
  [EmployeeLocation.FR]: [
    {
      type: LeaveType.CONGES_PAYES,
      label: LeaveLabel.CONGES_PAYES,
      icon: BeachAccessIcon,
      tooltip: LeaveTooltip[LeaveType.CONGES_PAYES],
    },
    {
      type: LeaveType.RTT,
      label: LeaveLabel.RTT,
      icon: ScheduleIcon,
      tooltip: LeaveTooltip[LeaveType.RTT],
    },
    {
      type: LeaveType.SICK,
      label: LeaveLabel.SICK,
      icon: LocalHospitalIcon,
    },
    {
      type: LeaveType.COMPASSIONATE,
      label: LeaveLabel.COMPASSIONATE,
      icon: HeartBrokenOutlinedIcon,
      tooltip: LeaveTooltip[LeaveType.COMPASSIONATE],
    },
    {
      type: LeaveType.OTHER_AUTHORIZED,
      label: LeaveLabel.OTHER_AUTHORIZED,
      icon: HandshakeOutlinedIcon,
      tooltip: LeaveTooltip[LeaveType.OTHER_AUTHORIZED],
    },
  ],
  [EmployeeLocation.ES]: [
    {
      type: LeaveType.ANNUAL,
      label: LeaveLabel.SPAIN_ANNUAL,
      icon: EventAvailableIcon,
    },
    {
      type: LeaveType.CASUAL,
      label: LeaveLabel.SPAIN_CASUAL,
      icon: WorkOffIcon,
    },
    {
      type: LeaveType.SICK,
      label: LeaveLabel.SICK,
      icon: LocalHospitalIcon,
    },
  ],
};

interface LeaveSelectionProps {
  daysSelected: number;
  selectedLeaveType: LeaveType;
  onLeaveTypeChange: (leaveType: LeaveType) => void;
  selectedDayPortion: DayPortion | null;
  onDayPortionChange: (dayPortion: DayPortion | null) => void;
  location: string | null;
}

export default function LeaveSelection({
  daysSelected,
  selectedLeaveType,
  onLeaveTypeChange,
  selectedDayPortion,
  onDayPortionChange,
  location,
}: LeaveSelectionProps) {
  const theme = useTheme();
  const isHalfDayDisabled = daysSelected !== 1;

  const leaveTypeOptions = useMemo<LeaveTypeOption[]>(() => {
    const locationSpecific =
      LOCATION_LEAVE_TYPES[location ?? EmployeeLocation.LK] ??
      LOCATION_LEAVE_TYPES[EmployeeLocation.LK];
    return [...locationSpecific, ...COMMON_LEAVE_TYPES];
  }, [location]);

  useEffect(() => {
    if (
      (daysSelected > 1 || selectedDayPortion === null) &&
      selectedDayPortion !== DayPortion.FULL
    ) {
      onDayPortionChange(DayPortion.FULL);
    }
  }, [daysSelected, selectedDayPortion, onDayPortionChange]);

  const handleLeaveTypeSelection = (leaveType: LeaveType) => {
    onLeaveTypeChange(leaveType);
  };

  const handleDayPortionSelection = (dayPortion: DayPortion) => {
    if (daysSelected > 1) return;
    onDayPortionChange(dayPortion);
  };

  return (
    <Stack direction="column" flex={1} gap={2.5}>
      {/* Leave Type */}
      <Stack direction="row" alignItems="center" gap={1}>
        <CategoryRoundedIcon sx={{ fontSize: 20, color: theme.palette.primary.main }} />
        <Typography variant="h6" sx={{ color: theme.palette.customText.primary.p1.active }}>
          Leave Type
        </Typography>
      </Stack>
      <Box
        display="grid"
        gridTemplateColumns="repeat(auto-fill, minmax(5rem, 1fr))"
        gap={1.5}
        width="100%"
      >
        {leaveTypeOptions.map((opt) => {
          const iconEl = (
            <LeaveSelectionIcon
              Icon={opt.icon}
              label={opt.label}
              isSelected={selectedLeaveType === opt.type}
              onClick={() => handleLeaveTypeSelection(opt.type)}
              info={opt.info}
            />
          );
          return opt.tooltip ? (
            <Tooltip key={opt.type} title={opt.tooltip} arrow placement="top">
              <Box>{iconEl}</Box>
            </Tooltip>
          ) : (
            <Box key={opt.type}>{iconEl}</Box>
          );
        })}
      </Box>

      {/* Portion of the day */}
      <Stack direction="row" alignItems="center" gap={1} mt={1}>
        <TimerRoundedIcon sx={{ fontSize: 20, color: theme.palette.primary.main }} />
        <Typography variant="h6" sx={{ color: theme.palette.customText.primary.p1.active }}>
          Portion of the day
        </Typography>
      </Stack>
      <Stack direction="row" gap={1.5}>
        <DatePill
          partOfDay={DayPortionLabel.FULL}
          isSelected={selectedDayPortion === DayPortion.FULL}
          onClick={() => handleDayPortionSelection(DayPortion.FULL)}
        />
        <DatePill
          partOfDay={DayPortionLabel.FIRST}
          isSelected={selectedDayPortion === DayPortion.FIRST}
          onClick={
            isHalfDayDisabled ? undefined : () => handleDayPortionSelection(DayPortion.FIRST)
          }
          disabled={isHalfDayDisabled}
        />
        <DatePill
          partOfDay={DayPortionLabel.SECOND}
          isSelected={selectedDayPortion === DayPortion.SECOND}
          onClick={
            isHalfDayDisabled ? undefined : () => handleDayPortionSelection(DayPortion.SECOND)
          }
          disabled={isHalfDayDisabled}
        />
      </Stack>
    </Stack>
  );
}
