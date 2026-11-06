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

// Two views share this page: Permanent Employees (from GET /employee-hub/employees)
// and Interns (from GET /intern-profiles). There is no page-level filter bar;
// the Overview tabs reflect the whole roster, and the Explore tabs handle
// filtering.

import React, { Fragment, useEffect, useMemo, useState } from "react";
import { useLocation, useNavigate } from "react-router-dom";
import Papa from "papaparse";
import {
  Box, Card, CardContent, Typography, Grid,
  Button, ButtonGroup, LinearProgress, Stack,
  IconButton, Dialog, DialogTitle, DialogContent, Tabs, Tab, Avatar,
  InputAdornment, Popover, Skeleton, Tooltip, Alert,
  useTheme, useMediaQuery, TextField, alpha, Select, MenuItem, FormControl, Checkbox, ListItemText, InputLabel,
} from "@mui/material";
import { LocalizationProvider } from "@mui/x-date-pickers/LocalizationProvider";
import { AdapterDayjs } from "@mui/x-date-pickers/AdapterDayjs";
import { DateCalendar } from "@mui/x-date-pickers/DateCalendar";
import { PickersDay } from "@mui/x-date-pickers/PickersDay";
import type { PickerSelectionState } from "@mui/x-date-pickers/internals";
import dayjs from "dayjs";
import {
  ResponsiveContainer, LineChart, BarChart,
  XAxis, YAxis, CartesianGrid, Tooltip as RechartsTooltip, Legend,
  Bar, Line,
} from "recharts";
import BarChartIcon from "@mui/icons-material/BarChart";
import CalendarTodayIcon from "@mui/icons-material/CalendarToday";
import DownloadIcon from "@mui/icons-material/Download";
import RefreshIcon from "@mui/icons-material/Refresh";
import TrendingUpIcon from "@mui/icons-material/TrendingUp";
import GroupsIcon from "@mui/icons-material/Groups";
import PersonAddIcon from "@mui/icons-material/PersonAdd";
import HowToRegIcon from "@mui/icons-material/HowToReg";
import ArrowCircleRightIcon from "@mui/icons-material/ArrowCircleRight";
import TimerIcon from "@mui/icons-material/Timer";
import LogoutIcon from "@mui/icons-material/Logout";
import SchoolIcon from "@mui/icons-material/School";
import AccessTimeIcon from "@mui/icons-material/AccessTime";
import AccountBalanceIcon from "@mui/icons-material/AccountBalance";
import LayersIcon from "@mui/icons-material/Layers";
import DeviceHubIcon from "@mui/icons-material/DeviceHub";
import InboxIcon from "@mui/icons-material/Inbox";
import PieChartIcon from "@mui/icons-material/PieChart";
import PercentIcon from "@mui/icons-material/Percent";
import CloseIcon from "@mui/icons-material/Close";
import DashboardIcon from "@mui/icons-material/Dashboard";
import TableChartIcon from "@mui/icons-material/TableChart";
import ArrowForwardIcon from "@mui/icons-material/ArrowForward";
import KeyboardArrowUpIcon from "@mui/icons-material/KeyboardArrowUp";
import KeyboardArrowDownIcon from "@mui/icons-material/KeyboardArrowDown";
import UnfoldMoreIcon from "@mui/icons-material/UnfoldMore";
import SearchIcon from "@mui/icons-material/Search";
import FilterListIcon from "@mui/icons-material/FilterList";
import { useEmployeeHub } from "@hooks/useEmployeeHub";
import { useEmployeeHubBootstrap } from "@hooks/useEmployeeHubBootstrap";
import { useEmployeeHubColors, type EmployeeHubColors } from "@hooks/useEmployeeHubColors";
import {
  parseDate, isSameMonthAndYear, startOfDay,
  formatDateToken as format, isDateToday as isToday, formatReadableDate,
} from "@utils/employeeHub/dateHelpers";
import { summariseInternMonth } from "@utils/employeeHub/internMonthSummary";
import { isEndedStatus, getStatusDisplay } from "@utils/employeeHub/statusHelpers";
import { resolveNameByEmail, buildEmailLookup, emailKey } from "@utils/employeeHub/internHelpers";
import type { EmployeeRow, InternRow } from "@slices/employeeHubSlice/employeeHub";
import { EmployeeStatus } from "@/types/types";

type ViewKind = "interns" | "employees";

type PersonModal = { title: string; subtitle: string } & (
  | { kind: "interns"; rows: InternRow[] }
  | { kind: "employees"; rows: EmployeeRow[] }
);


// Some source rows carry a literal "0" (or similar placeholder) in fields
// like BU where the sheet was left blank and auto-filled by a formula -
// treated as blank here so it falls through to "Unspecified" everywhere,
// instead of showing up as its own nonsense group.
const JUNK_VALUE_PATTERN = /^(0|n\/?a|null|undefined|none|-|unspecified)$/i;
const normalize = (v: unknown) => {
  const s = String(v || "").trim();
  return JUNK_VALUE_PATTERN.test(s) ? "" : s;
};

// Team/business-unit/sub-team names can differ in casing between rows (e.g.
// "ENGINEERING" vs "Engineering"). Grouping on the raw string would split one
// real team/BU/sub-team into two separate bars/rows, so every place that
// aggregates by one of these three fields canonicalizes the key through this
// function (upper case) to merge them into a single, consistently-labeled group.
const canonicalGroupKey = (v: unknown): string => {
  const s = normalize(v);
  return s ? s.toUpperCase() : "";
};

const isActiveStatus = (i: InternRow) => getStatusDisplay(i.status).colorKey === "active";

// Pyramid levels by designation.job_band, most senior first: bands 1-4
// (only a handful of people) share the base level, every band above that is
// its own level. Bands in the data run 1-14; band 0 (interns, Enterprise Account Executives) and
// designations with no band set fall into NO_BAND_TIER and are reported
// separately rather than placed on the pyramid.
const JOB_BAND_TIERS = [
  { key: "Band 14", min: 14, max: 14 },
  { key: "Band 13", min: 13, max: 13 },
  { key: "Band 12", min: 12, max: 12 },
  { key: "Band 11", min: 11, max: 11 },
  { key: "Band 10", min: 10, max: 10 },
  { key: "Band 9", min: 9, max: 9 },
  { key: "Band 8", min: 8, max: 8 },
  { key: "Band 7", min: 7, max: 7 },
  { key: "Band 6", min: 6, max: 6 },
  { key: "Band 5", min: 5, max: 5 },
  { key: "Band 1-4", min: 1, max: 4 },
] as const;
const NO_BAND_TIER = "No Band";
const ALL_TEAMS = "__all__";
function tierForJobBand(band: number | null | undefined): string {
  if (band == null) return NO_BAND_TIER;
  return JOB_BAND_TIERS.find((t) => band >= t.min && band <= t.max)?.key ?? NO_BAND_TIER;
}

// The Permanent Employees view excludes interns, so these are the real
// non-intern employment_type values (see formatEmploymentType in
// employeeApiData.ts). Fixed colors so a type keeps its color across charts;
// anything new falls back to C.muted.
const EMPLOYMENT_TYPE_COLOR_KEYS: Record<string, "teal" | "orange" | "purple" | "blue" | "yellow" | "red"> = {
  "Permanent": "teal",
  "Probation": "orange",
  "Consultancy": "purple",
  "Advisory Consultant": "blue",
  "Part Time Consultancy": "yellow",
  "Fixed Term": "red",
};

const TENURE_GROUPS = ["<1 yr", "1-3 yrs", "3-5 yrs", "5-10 yrs", "10-20 yrs", "20+ yrs"] as const;
const tenureGroup = (years: number) =>
  years < 1 ? "<1 yr" : years < 3 ? "1-3 yrs" : years < 5 ? "3-5 yrs" : years < 10 ? "5-10 yrs" : years < 20 ? "10-20 yrs" : "20+ yrs";
const yearsBetween = (from: Date, to: Date) => (to.getTime() - from.getTime()) / (365.25 * 24 * 3600 * 1000);
const genderLabel = (g: unknown) => { const v = String(g || "").trim().toLowerCase(); return v.startsWith("m") ? "Male" : v.startsWith("f") ? "Female" : "Not recorded"; };
// Pyramid/table order: junior -> senior, then No Band.
const JOB_BAND_ORDER_JUNIOR_FIRST = [...[...JOB_BAND_TIERS].reverse().map((t) => t.key as string), NO_BAND_TIER];

// Types present in `rows`, largest first.
const employmentTypesIn = (rows: EmployeeRow[]) =>
  countBy(rows, (e) => e.employmentType || "Unspecified").map((d) => d.name);

// Final day of employment has passed (or is today) - i.e. the person has
// actually left, whether or not the scheduler has flipped them to "Left" yet.
const departureDate = (e: EmployeeRow): Date | null => {
  const f = parseDate(e.finalDayOfEmployment);
  return f && f <= new Date() ? f : null;
};

// A "Left" employee with no final day on record left on an unknown date, so
// they can't be placed in any point-in-time headcount.
const hasUnknownDeparture = (e: EmployeeRow) =>
  e.status === EmployeeStatus.Left && !parseDate(e.finalDayOfEmployment);

const countBy = <T,>(rows: T[], getKey: (row: T) => unknown) => {
  const counts: Record<string, number> = {};
  rows.forEach((row) => {
    const key = normalize(getKey(row)) || "Unknown";
    counts[key] = (counts[key] || 0) + 1;
  });
  return Object.entries(counts).map(([name, value]) => ({ name, value })).sort((a, b) => b.value - a.value);
};

// Same idea as countBy, but for grouping by a *person* (a mentor or a
// reporting manager) resolved from an email column - also carries that
// person's employeeId along, so the resulting row can link to their real
// people-app profile instead of just being a display label.
const countByPerson = <T,>(rows: T[], getEmail: (row: T) => string, employeesByEmail: Map<string, EmployeeRow>) => {
  const counts: Record<string, { name: string; value: number; id: string | null }> = {};
  rows.forEach((row) => {
    const email = emailKey(getEmail(row));
    if (!email) return; // No one assigned - excluded rather than ranked as a "—" entry.
    const name = normalize(resolveNameByEmail(email, employeesByEmail)) || "Unknown";
    if (!counts[name]) {
      counts[name] = { name, value: 0, id: employeesByEmail.get(email)?.employeeId ?? null };
    }
    counts[name].value += 1;
  });
  return Object.values(counts).sort((a, b) => b.value - a.value);
};

// `C.hover` (a translucent row-hover tint) was being used as the tooltip's
// background - fine for a table row, but a floating tooltip needs an opaque
// surface or whatever's behind it (chart lines/bars) bleeds through. Also
// missing `itemStyle`: without it, recharts colors each value by its own
// series color, which can end up low-contrast against the background -
// forcing it to C.text keeps every value readable regardless of series color.
const rechartsTooltipProps = (C: EmployeeHubColors) => ({
  contentStyle: {
    backgroundColor: C.surface,
    border: `1px solid ${C.border}`,
    borderRadius: "4px",
    fontSize: "11px",
    boxShadow: "0 4px 16px -4px rgba(0,0,0,0.35)",
  },
  labelStyle: { color: C.text, fontWeight: 600, marginBottom: 2 },
  itemStyle: { color: C.text },
});

// Fixed height (scrolls inside) so the by-team and by-location tables line
// up at the same size side by side.
const GenderBreakdownTable = ({ data }: any) => {
  const C = useEmployeeHubColors();
  if (!data || data.rows.length === 0) return <EmptyState />;
  const barCell = (pct: number, color: string) => (
    <Box sx={{ display: "flex", alignItems: "center", gap: 0.75 }}>
      <Box sx={{ width: 36, height: 4, borderRadius: 3, backgroundColor: C.border, overflow: "hidden" }}>
        <Box sx={{ width: `${pct}%`, height: "100%", backgroundColor: color }} />
      </Box>
      <Typography sx={{ fontSize: "9.5px", color: C.subtle, fontFamily: "monospace", minWidth: 34 }}>{pct.toFixed(1)}%</Typography>
    </Box>
  );
  const cell = { py: 0.5, borderBottom: `1px solid ${C.border}` };
  return (
    <Box sx={{ height: 280, overflow: "auto" }}>
      <Box component="table" sx={{ width: "100%", borderCollapse: "collapse", fontSize: "10px" }}>
        <Box component="thead">
          <Box component="tr">
            {["", "Total", "Male", "Female"].map((h) => (
              <Box component="th" key={h} sx={{ textAlign: "left", py: 0.75, color: C.muted, fontWeight: 600, fontFamily: "monospace", fontSize: "9px", textTransform: "uppercase", letterSpacing: "0.06em", borderBottom: `1px solid ${C.border}`, position: "sticky", top: 0, backgroundColor: C.surface }}>
                {h}
              </Box>
            ))}
          </Box>
        </Box>
        <Box component="tbody">
          <Box component="tr">
            <Box component="td" sx={{ ...cell, color: C.text, fontSize: "10.5px", fontWeight: 700 }}>All</Box>
            <Box component="td" sx={{ ...cell, color: C.text, fontFamily: "monospace", fontWeight: 700 }}>{data.grand.total}</Box>
            <Box component="td" sx={cell}>{barCell(data.grand.pctMale, C.blue)}</Box>
            <Box component="td" sx={cell}>{barCell(data.grand.pctFemale, C.purple)}</Box>
          </Box>
          {data.rows.map((r: any) => (
            <Box component="tr" key={r.name} sx={{ "&:hover": { backgroundColor: C.hover } }}>
              <Box component="td" sx={{ ...cell, color: C.text, fontSize: "10.5px", maxWidth: 160, overflow: "hidden", textOverflow: "ellipsis", whiteSpace: "nowrap" }} title={r.name}>{r.name}</Box>
              <Box component="td" sx={{ ...cell, color: C.subtle, fontFamily: "monospace" }}>{r.total}</Box>
              <Box component="td" sx={cell}>{barCell(r.pctMale, C.blue)}</Box>
              <Box component="td" sx={cell}>{barCell(r.pctFemale, C.purple)}</Box>
            </Box>
          ))}
        </Box>
      </Box>
    </Box>
  );
};

// Built as a plain Card rather than a design-system StatCard - lays out
// icon + value + label with a colored top accent bar, matching the source
// page's KPI tile look.
const KPICard = ({ label, value, subtext, color, icon: Icon, onClick }: any) => {
  const C = useEmployeeHubColors();
  const c = color || C.text;
  const tooltipTitle = subtext || (onClick ? "Click to view list" : "");
  const card = (
    <Card
      {...(onClick ? { component: "button", type: "button", onClick, "aria-label": `${label}: ${value}${subtext ? `, ${subtext}` : ""}` } : {})}
      sx={{
        backgroundColor: C.surface,
        border: `1px solid ${C.border}`, borderRadius: "8px", position: "relative", overflow: "hidden",
        cursor: onClick ? "pointer" : "default", textAlign: "left", font: "inherit", display: "block", width: "100%",
        transition: "border-color 0.2s, box-shadow 0.2s, transform 0.15s",
        "&::before": { content: '""', position: "absolute", top: 0, left: 0, right: 0, height: "2px", backgroundColor: c, opacity: 0.85 },
        "&:hover": { borderColor: c, boxShadow: `0 0 0 1px ${c}22`, transform: "translateY(-1px)" },
        "&:focus-visible": { outline: `2px solid ${c}`, outlineOffset: "2px" },
      }}
    >
      <CardContent sx={{ p: "14px 16px !important", display: "flex", alignItems: "center", gap: 1.25 }}>
        {Icon && <Icon sx={{ fontSize: 18, color: c }} />}
        <Box>
          <Typography sx={{ fontSize: "26px", fontWeight: 700, fontFamily: "monospace", color: c, lineHeight: 1 }}>{value}</Typography>
          <Typography sx={{ fontSize: "10px", textTransform: "uppercase", letterSpacing: "0.1em", color: C.muted, fontWeight: 600, fontFamily: "monospace", mt: 0.5 }}>{label}</Typography>
        </Box>
      </CardContent>
    </Card>
  );
  return tooltipTitle ? <Tooltip title={tooltipTitle} arrow placement="top">{card}</Tooltip> : card;
};

// `onClick` is optional - when passed (a person's name resolved to a real,
// live employeeId), the label renders as a link to their people-app
// profile instead of plain text. Group names (BU/team/university) never
// pass it, since there's no profile to link a group name to.
const InsightRow = ({ label, value, max, color, onClick }: any) => {
  const C = useEmployeeHubColors();
  const c = color || C.orange;
  return (
    <Box sx={{ display: "flex", alignItems: "center", gap: 1.5 }}>
      <Typography
        component={onClick ? "button" : "span"}
        type={onClick ? "button" : undefined}
        onClick={onClick}
        sx={{
          width: { xs: 100, sm: 130 }, fontSize: "11px", overflow: "hidden", textOverflow: "ellipsis", whiteSpace: "nowrap", flexShrink: 0,
          ...(onClick
            ? { color: C.orange, cursor: "pointer", background: "none", border: "none", p: 0, font: "inherit", textAlign: "left", "&:hover": { color: C.orangeHover } }
            : { color: C.subtle }),
        }}
        title={label}
      >
        {label}
      </Typography>
      <LinearProgress variant="determinate" value={max ? (value / max) * 100 : 0}
        sx={{ flex: 1, height: 5, borderRadius: 3, backgroundColor: C.border, "& .MuiLinearProgress-bar": { backgroundColor: c, borderRadius: 3 } }}
      />
      <Typography sx={{ width: 28, fontSize: "11px", fontFamily: "monospace", color: c, fontWeight: 700, textAlign: "right", flexShrink: 0 }}>
        {value}
      </Typography>
    </Box>
  );
};

const EmptyState = ({ label = "No data yet" }: any) => {
  const C = useEmployeeHubColors();
  return (
    <Box sx={{ display: "flex", flexDirection: "column", alignItems: "center", justifyContent: "center", gap: 1, py: 3, opacity: 0.6 }}>
      <InboxIcon sx={{ fontSize: 20, color: C.muted }} />
      <Typography sx={{ fontSize: "11px", color: C.muted, fontFamily: "monospace" }}>{label}</Typography>
    </Box>
  );
};

const SectionCard = ({ title, children, icon: Icon, subtitle, sx: sxProp = {} }: any) => {
  const C = useEmployeeHubColors();
  return (
    <Card sx={{
      backgroundColor: C.surface, border: `1px solid ${C.border}`, borderRadius: "10px", height: "100%", width: "100%",
      transition: "border-color 0.2s, box-shadow 0.2s",
      "&:hover": { borderColor: alpha(C.orange, 0.35), boxShadow: `0 4px 18px -10px ${alpha(C.orange, 0.5)}` },
      ...sxProp,
    }}>
      <CardContent sx={{ p: "16px 18px !important" }}>
        <Box sx={{ mb: 2, display: "flex", alignItems: "flex-start", gap: 1.25 }}>
          {Icon && (
            <Box sx={{ width: 28, height: 28, borderRadius: "8px", backgroundColor: alpha(C.orange, 0.12), display: "flex", alignItems: "center", justifyContent: "center", flexShrink: 0 }}>
              <Icon sx={{ fontSize: 15, color: C.orange }} />
            </Box>
          )}
          <Box sx={{ minWidth: 0 }}>
            <Typography sx={{ fontSize: "13.5px", fontWeight: 700, color: C.text, lineHeight: 1.3 }}>{title}</Typography>
            {subtitle && <Typography sx={{ fontSize: "11.5px", color: C.muted, mt: 0.25 }}>{subtitle}</Typography>}
          </Box>
        </Box>
        {children}
      </CardContent>
    </Card>
  );
};

// Wrapping row of cards where each card grows to fill the row, so hiding
// one card (e.g. a chart for a filter narrowed to one value) lets the others
// widen into the gap instead of leaving an empty slot.
const Flow = ({ children }: { children: React.ReactNode }) => (
  <Box sx={{ display: "flex", flexWrap: "wrap", gap: 2, alignItems: "stretch" }}>{children}</Box>
);
const FlowItem = ({ basis = 360, full = false, children }: { basis?: number; full?: boolean; children: React.ReactNode }) => (
  <Box sx={{ flex: full ? "1 1 100%" : `1 1 ${basis}px`, minWidth: 0, display: "flex" }}>{children}</Box>
);


// Horizontal stacked bars: one bar per group, split by `keys`.
const StackedBarCard = ({ title, icon, subtitle, rows, keys, colors, emptyLabel }: {
  title: string; icon: any; subtitle?: string; rows: Record<string, any>[]; keys: string[]; colors: Record<string, string>; emptyLabel?: string;
}) => {
  const C = useEmployeeHubColors();
  const isPhone = useMediaQuery(useTheme().breakpoints.down("sm"));
  return (
    <SectionCard title={title} icon={icon} subtitle={subtitle}>
      {rows.length ? (
        <Box sx={{ height: Math.max(220, rows.length * 32 + 40) }}>
          <ResponsiveContainer width="100%" height="100%">
            <BarChart data={rows} layout="vertical" barSize={16} margin={{ left: 8, right: 16 }}>
              <CartesianGrid stroke={C.border} strokeDasharray="4 4" horizontal={false} />
              <XAxis type="number" stroke={C.border} tick={{ fill: C.muted, fontSize: 9, fontFamily: "monospace" }} tickLine={false} axisLine={false} allowDecimals={false} />
              <YAxis type="category" dataKey="name" stroke={C.border} tick={{ fill: C.text, fontSize: 10.5 }} tickLine={false} axisLine={false} width={isPhone ? 90 : 150} />
              <RechartsTooltip {...rechartsTooltipProps(C)} cursor={{ fill: C.hover }} />
              <Legend wrapperStyle={{ fontSize: 11, color: C.muted }} iconType="circle" iconSize={8} />
              {keys.map((k, i) => (
                <Bar key={k} dataKey={k} stackId="s" fill={colors[k] || C.muted} radius={i === keys.length - 1 ? [0, 4, 4, 0] : [0, 0, 0, 0]} />
              ))}
            </BarChart>
          </ResponsiveContainer>
        </Box>
      ) : <EmptyState label={emptyLabel} />}
    </SectionCard>
  );
};



// ---- Explore tab ----
// One card per way of splitting the selected people (by team, by gender, ...).
// Rows are plain HTML bars so every card looks the same; clicking a row
// narrows the filters to that value (when the card maps to a filter).
type ExploreDimension = {
  key: string; title: string; icon: any; color: string;
  data: { name: string; value: number }[];
  filterKey?: string; // clicking a row sets this filter to that row's value
  keepOrder?: boolean; // ordered groups (job band, years, ...) keep their order and show all rows
};

// Multi-select filter for the Explore tabs. Empty selection = all.
const MultiFilter = ({ label, options, value, onChange }: {
  label: string; options: { name: string; value: number }[]; value: string[]; onChange: (v: string[]) => void;
}) => {
  const C = useEmployeeHubColors();
  return (
    <FormControl size="small" fullWidth>
      <InputLabel shrink sx={{ color: C.muted, fontSize: "12px", "&.Mui-focused": { color: C.orange } }}>{label}</InputLabel>
      <Select
        multiple displayEmpty notched label={label} value={value}
        onChange={(ev) => onChange(typeof ev.target.value === "string" ? ev.target.value.split(",") : ev.target.value)}
        renderValue={(sel) => (sel.length === 0 ? "All" : sel.length === 1 ? sel[0] : `${sel.length} selected`)}
        MenuProps={{ PaperProps: { sx: { maxHeight: 360 } } }}
        sx={{
          backgroundColor: C.bg, color: value.length ? C.orange : C.text, fontSize: "12.5px",
          "& .MuiOutlinedInput-notchedOutline": { borderColor: value.length ? C.orange : C.border },
          "&:hover .MuiOutlinedInput-notchedOutline": { borderColor: C.orange },
          "&.Mui-focused .MuiOutlinedInput-notchedOutline": { borderColor: C.orange },
        }}
      >
        {options.map((o) => (
          <MenuItem key={o.name} value={o.name} dense>
            <Checkbox size="small" checked={value.includes(o.name)} sx={{ p: 0.5, mr: 1, "&.Mui-checked": { color: C.orange } }} />
            <ListItemText primary={o.name} secondary={o.value} primaryTypographyProps={{ fontSize: "12.5px" }}
              secondaryTypographyProps={{ fontSize: "10.5px" }} sx={{ display: "flex", justifyContent: "space-between", gap: 2, m: 0 }} />
          </MenuItem>
        ))}
      </Select>
    </FormControl>
  );
};

const BREAKDOWN_ROWS = 8;
// The app header is fixed (dense toolbar, 48px); the dashboard's sub-tab bar
// pins right under it, and the sticky Explore parts pin under the tab bar.
// Their wrappers carry the page background, so content scrolling up is hidden
// behind them instead of showing through the gap above the cards.
const APP_HEADER_HEIGHT = 48;
const SUB_TABS_HEIGHT = 37;
const EXPLORE_STICKY_TOP = APP_HEADER_HEIGHT + SUB_TABS_HEIGHT;
const BreakdownCard = ({ dim, onPick }: { dim: ExploreDimension; onPick?: (filterKey: string, value: string) => void }) => {
  const C = useEmployeeHubColors();
  const [expanded, setExpanded] = useState(false);
  const rows = dim.keepOrder || expanded ? dim.data : dim.data.slice(0, BREAKDOWN_ROWS);
  const max = Math.max(1, ...dim.data.map((d) => d.value));
  const clickable = !!(dim.filterKey && onPick);
  const Icon = dim.icon;
  return (
    <Card sx={{ backgroundColor: C.surface, border: `1px solid ${C.border}`, borderRadius: "12px", width: "100%", display: "flex", flexDirection: "column" }}>
      <Box sx={{ px: 2, pt: 1.75, pb: 1.25, display: "flex", alignItems: "center", gap: 1 }}>
        <Box sx={{ width: 26, height: 26, borderRadius: "7px", backgroundColor: alpha(dim.color, 0.14), display: "flex", alignItems: "center", justifyContent: "center" }}>
          <Icon sx={{ fontSize: 14, color: dim.color }} />
        </Box>
        <Typography sx={{ fontSize: "13.5px", fontWeight: 700, color: C.text, flex: 1 }}>{dim.title}</Typography>
        <Typography sx={{ fontSize: "11px", color: C.muted }}>{dim.data.length} {dim.data.length === 1 ? "group" : "groups"}</Typography>
      </Box>
      <Box sx={{ px: 1, pb: 1, flex: 1 }}>
        {rows.length ? rows.map((d) => (
          <Box key={d.name}
            component={clickable ? "button" : "div"}
            type={clickable ? "button" : undefined}
            onClick={clickable ? () => onPick!(dim.filterKey!, d.name) : undefined}
            title={clickable ? `Show only ${d.name}` : d.name}
            sx={{
              display: "grid", gridTemplateColumns: "minmax(90px, 40%) 1fr 44px", alignItems: "center", gap: 1.25,
              width: "100%", px: 1, py: 0.7, borderRadius: "8px", border: "none", background: "none", font: "inherit", textAlign: "left",
              cursor: clickable ? "pointer" : "default",
              "&:hover": clickable ? { backgroundColor: C.hover, "& .bd-label": { color: dim.color } } : {},
              "&:focus-visible": { outline: `2px solid ${dim.color}`, outlineOffset: "-2px" },
            }}>
            <Typography className="bd-label" sx={{ fontSize: "12px", color: C.subtle, overflow: "hidden", textOverflow: "ellipsis", whiteSpace: "nowrap" }}>{d.name}</Typography>
            <Box sx={{ height: 8, borderRadius: 4, backgroundColor: alpha(dim.color, 0.1), overflow: "hidden" }}>
              <Box sx={{ width: `${(d.value / max) * 100}%`, minWidth: d.value ? 4 : 0, height: "100%", borderRadius: 4, backgroundColor: dim.color }} />
            </Box>
            <Typography sx={{ fontSize: "12px", fontWeight: 700, color: C.text, fontFamily: "monospace", textAlign: "right" }}>{d.value.toLocaleString()}</Typography>
          </Box>
        )) : <EmptyState />}
      </Box>
      {!dim.keepOrder && dim.data.length > BREAKDOWN_ROWS && (
        <Button size="small" onClick={() => setExpanded((v) => !v)}
          sx={{ m: 1, mt: 0, alignSelf: "flex-start", textTransform: "none", fontSize: "11.5px", color: dim.color }}>
          {expanded ? "Show less" : `Show all ${dim.data.length}`}
        </Button>
      )}
    </Card>
  );
};

const ExplorePanel = ({
  noun, fields, options, filters, setFilters, joinedFrom, setJoinedFrom, joinedTo, setJoinedTo, onClear,
  shown, total, onViewList, stats, timeline, dimensions,
}: {
  noun: string;
  fields: { key: string; label: string }[];
  options: Record<string, { name: string; value: number }[]>;
  filters: Record<string, string[]>;
  setFilters: React.Dispatch<React.SetStateAction<Record<string, string[]>>>;
  joinedFrom: string; setJoinedFrom: (v: string) => void;
  joinedTo: string; setJoinedTo: (v: string) => void;
  onClear: () => void;
  shown: number; total: number; onViewList: () => void;
  stats: { label: string; value: string | number; color: string }[];
  timeline: { name: string; value: number }[];
  dimensions: ExploreDimension[];
}) => {
  const C = useEmployeeHubColors();
  // Below lg the filters sit above the results; folded by default so the
  // results are visible straight away, and the summary isn't pinned (it would
  // cover too much of a small screen).
  const isWide = useMediaQuery(useTheme().breakpoints.up("lg"));
  const [filtersOpen, setFiltersOpen] = useState(false);
  const chips = [
    ...fields.flatMap((f) => (filters[f.key] || []).map((v) => ({ id: `${f.key}:${v}`, label: `${f.label}: ${v}`, remove: () => setFilters((p) => ({ ...p, [f.key]: (p[f.key] || []).filter((x) => x !== v) })) }))),
    ...(joinedFrom ? [{ id: "from", label: `Joined from ${joinedFrom}`, remove: () => setJoinedFrom("") }] : []),
    ...(joinedTo ? [{ id: "to", label: `Joined until ${joinedTo}`, remove: () => setJoinedTo("") }] : []),
  ];
  const pick = (key: string, value: string) => setFilters((p) => ({ ...p, [key]: [value] }));
  // A card is left out when its own filter is narrowed to one value - it
  // would only ever show a single full bar.
  const visible = dimensions.filter((d) => !(d.filterKey && (filters[d.filterKey] || []).length === 1));
  const dateSx = {
    "& .MuiOutlinedInput-root": { backgroundColor: C.bg, fontSize: "12.5px", color: C.text },
    "& .MuiOutlinedInput-notchedOutline": { borderColor: C.border },
    "& .MuiInputLabel-root": { color: C.muted, fontSize: "12px" },
  };
  return (
    <Box sx={{ display: "grid", gridTemplateColumns: { xs: "1fr", lg: "260px minmax(0, 1fr)" }, gap: 2, alignItems: "start" }}>
      {/* Filters */}
      {/* Sticks below the app's fixed top bar; scrolls inside when taller than the window. */}
      <Box sx={{
        position: { lg: "sticky" }, top: { lg: EXPLORE_STICKY_TOP }, zIndex: 3, backgroundColor: C.bg,
        pt: { lg: 1.5 }, mt: { lg: -1.5 },
      }}>
      <Card sx={{
        backgroundColor: C.surface, border: `1px solid ${C.border}`, borderRadius: "12px",
        maxHeight: { lg: `calc(100vh - ${EXPLORE_STICKY_TOP + 28}px)` },
        display: "flex", flexDirection: "column",
      }}>
        <Box sx={{ px: 2, py: 1.5, display: "flex", alignItems: "center", gap: 1, borderBottom: `1px solid ${C.border}` }}>
          <FilterListIcon sx={{ fontSize: 16, color: C.orange }} />
          <Typography sx={{ fontSize: "13.5px", fontWeight: 700, color: C.text, flex: 1 }}>
            Filters{!isWide && chips.length ? ` (${chips.length})` : ""}
          </Typography>
          <Button size="small" disabled={!chips.length} onClick={onClear} sx={{ textTransform: "none", fontSize: "11.5px", color: C.orange, minWidth: 0 }}>Clear all</Button>
          {!isWide && (
            <Button size="small" variant="outlined" onClick={() => setFiltersOpen((o) => !o)} aria-expanded={filtersOpen}
              sx={{ textTransform: "none", fontSize: "11.5px", color: C.text, borderColor: C.border, minWidth: 0, ml: 0.5 }}>
              {filtersOpen ? "Hide" : "Show"}
            </Button>
          )}
        </Box>
        <Stack spacing={1.75} sx={{
          display: isWide || filtersOpen ? "flex" : "none",
          p: 2, flex: 1, minHeight: 0, overflowY: "auto", scrollbarWidth: "thin",
          "&::-webkit-scrollbar": { width: 6 }, "&::-webkit-scrollbar-thumb": { backgroundColor: C.border, borderRadius: 3 },
        }}>
          {fields.map((f) => (
            <MultiFilter key={f.key} label={f.label} options={options[f.key] || []} value={filters[f.key] || []}
              onChange={(v) => setFilters((p) => ({ ...p, [f.key]: v }))} />
          ))}
          <TextField size="small" type="date" label="Joined from" value={joinedFrom} onChange={(e) => setJoinedFrom(e.target.value)} InputLabelProps={{ shrink: true }} sx={dateSx} />
          <TextField size="small" type="date" label="Joined until" value={joinedTo} onChange={(e) => setJoinedTo(e.target.value)} InputLabelProps={{ shrink: true }} sx={dateSx} />
        </Stack>
      </Card>
      </Box>

      {/* Results */}
      <Stack spacing={2} sx={{ minWidth: 0 }}>
        <Box sx={{ position: { lg: "sticky" }, top: { lg: EXPLORE_STICKY_TOP }, zIndex: 3, backgroundColor: C.bg, pt: { lg: 1.5 }, mt: { lg: -1.5 }, pb: { lg: 0.5 } }}>
        <Card sx={{
          backgroundColor: C.surface, border: `1px solid ${C.border}`, borderRadius: "12px", p: 2,
          boxShadow: `0 6px 16px -10px rgba(0,0,0,0.35)`,
        }}>
          <Box sx={{ display: "flex", alignItems: "center", gap: 2, flexWrap: "wrap" }}>
            <Box sx={{ flex: 1, minWidth: { xs: "100%", sm: 200 } }}>
              <Typography sx={{ fontSize: { xs: "20px", sm: "22px" }, fontWeight: 700, color: C.text, lineHeight: 1.1 }}>
                {shown.toLocaleString()} <Box component="span" sx={{ fontSize: "14px", fontWeight: 500, color: C.muted }}>of {total.toLocaleString()} {noun}</Box>
              </Typography>
              <Typography sx={{ fontSize: "11.5px", color: C.muted, mt: 0.5 }}>
                {chips.length ? "Click any bar below to narrow down further." : "Choose filters on the left, or click any bar below to narrow down."}
              </Typography>
            </Box>
            <Button variant="contained" size="small" disabled={!shown} onClick={onViewList}
              sx={{ textTransform: "none", fontSize: "12px", backgroundColor: C.orange, boxShadow: "none", borderRadius: "8px", px: 2, "&:hover": { backgroundColor: C.orangeHover, boxShadow: "none" } }}>
              See the list
            </Button>
          </Box>
          {shown > 0 && (
            <Box sx={{ display: "grid", gridTemplateColumns: { xs: "repeat(2, minmax(0, 1fr))", sm: "repeat(auto-fit, minmax(120px, 1fr))" }, gap: 1, mt: 1.5 }}>
              {stats.map((st) => (
                <Box key={st.label} sx={{ backgroundColor: C.bg, border: `1px solid ${C.border}`, borderLeft: `3px solid ${st.color}`, borderRadius: "8px", px: 1.5, py: 0.75 }}>
                  <Typography sx={{ fontSize: "11px", color: C.muted }}>{st.label}</Typography>
                  <Typography sx={{ fontSize: "18px", fontWeight: 700, color: st.color, fontFamily: "monospace", lineHeight: 1.15 }}>{st.value}</Typography>
                </Box>
              ))}
            </Box>
          )}
          {chips.length > 0 && (
            <Box sx={{ display: "flex", flexWrap: "wrap", gap: 0.75, mt: 1.5 }}>
              {chips.map((c) => (
                <Box key={c.id} component="button" type="button" onClick={c.remove} title="Remove this filter"
                  sx={{
                    display: "inline-flex", alignItems: "center", gap: 0.5, px: 1.1, py: 0.4, borderRadius: "999px", cursor: "pointer",
                    border: `1px solid ${alpha(C.orange, 0.4)}`, backgroundColor: alpha(C.orange, 0.1), color: C.text, font: "inherit", fontSize: "11.5px",
                    "&:hover": { backgroundColor: alpha(C.orange, 0.2) },
                  }}>
                  {c.label}<CloseIcon sx={{ fontSize: 13, color: C.orange }} />
                </Box>
              ))}
            </Box>
          )}
        </Card>
        </Box>

        {shown ? (
          <>

            <Card sx={{ backgroundColor: C.surface, border: `1px solid ${C.border}`, borderRadius: "12px", p: 2 }}>
              <Box sx={{ display: "flex", alignItems: "center", gap: 1, mb: 1.5 }}>
                <Box sx={{ width: 26, height: 26, borderRadius: "7px", backgroundColor: alpha(C.orange, 0.14), display: "flex", alignItems: "center", justifyContent: "center" }}>
                  <CalendarTodayIcon sx={{ fontSize: 14, color: C.orange }} />
                </Box>
                <Typography sx={{ fontSize: "13.5px", fontWeight: 700, color: C.text, flex: 1 }}>Joined Each Month</Typography>
                <Typography sx={{ fontSize: "11px", color: C.muted }}>Last 12 months</Typography>
              </Box>
              <Box sx={{ height: 180 }}>
                <ResponsiveContainer width="100%" height="100%">
                  <BarChart data={timeline} barCategoryGap="25%" margin={{ top: 16, right: 4, left: 0, bottom: 0 }}>
                    <CartesianGrid stroke={C.border} strokeDasharray="4 4" vertical={false} />
                    <XAxis dataKey="name" stroke={C.border} tick={{ fill: C.muted, fontSize: 10 }} tickLine={false} axisLine={false} interval={0} />
                    <YAxis stroke={C.border} tick={{ fill: C.muted, fontSize: 9 }} tickLine={false} axisLine={false} allowDecimals={false} width={28} />
                    <RechartsTooltip {...rechartsTooltipProps(C)} cursor={{ fill: C.hover }} />
                    <Bar dataKey="value" name="Joined" fill={C.orange} radius={[4, 4, 0, 0]} label={{ position: "top", fill: C.muted, fontSize: 10 }} />
                  </BarChart>
                </ResponsiveContainer>
              </Box>
            </Card>

            {/* Packed columns: each card is only as tall as its list, and the
                next card sits right under it - no gaps under short cards. */}
            <Box sx={{ columnWidth: { xs: "auto", sm: "330px" }, columnCount: { xs: 1, sm: "auto" }, columnGap: "16px" }}>
              {visible.map((d) => (
                <Box key={d.key} sx={{ breakInside: "avoid", mb: 2, display: "flex" }}>
                  <BreakdownCard dim={d} onPick={pick} />
                </Box>
              ))}
            </Box>
          </>
        ) : (
          <Card sx={{ backgroundColor: C.surface, border: `1px solid ${C.border}`, borderRadius: "12px" }}>
            <EmptyState label={`No ${noun} found. Try removing a filter.`} />
          </Card>
        )}
      </Stack>
    </Box>
  );
};

// Custom day cell for the snapshot-date DateCalendar: renders the normal
// MUI X day button, plus a small teal/red dot underneath for days that have
// a join or end event.
function CalendarDayCell(props: any) {
  const { day, joinDates, endDates, ...other } = props;
  const C = useEmployeeHubColors();
  // The empty cells before the 1st and after the last day still render a
  // (hidden) day of the next/previous month; a dot there would sit under a
  // blank cell, so those days get none.
  const hidden = other.outsideCurrentMonth && !other.showDaysOutsideCurrentMonth;
  // joinDates/endDates are sets of "YYYY-MM-DD" keys, so each cell is a lookup.
  const key = day.format("YYYY-MM-DD");
  const joined = !hidden && joinDates?.has(key);
  const ended = !hidden && endDates?.has(key);
  const dots = [joined && C.teal, ended && C.red].filter(Boolean) as string[];
  return (
    <Box sx={{ position: "relative", display: "inline-flex" }}>
      <PickersDay {...other} day={day} />
      {dots.length > 0 && (
        <Box sx={{
          position: "absolute", bottom: 3, left: "50%", transform: "translateX(-50%)",
          display: "flex", gap: "2px", pointerEvents: "none",
        }}>
          {dots.map((color) => (
            <Box key={color} sx={{ width: 4, height: 4, borderRadius: "50%", backgroundColor: color }} />
          ))}
        </Box>
      )}
    </Box>
  );
}

const dateKey = (d: Date | null): string | null => (d ? format(d, "yyyy-MM-dd") : null);

const internHasEnded = (intern: InternRow) => isEndedStatus(intern.status);

// An intern who left before their agreement end date is already Ended while that
// date is still ahead; the internship will not end then, so it is not shown as
// an upcoming end.
const leftBeforeEndDate = (intern: InternRow, today: Date): boolean => {
  const e = parseDate(intern.endDate);
  return !!e && e >= today && internHasEnded(intern);
};

// Connected-stage strip: each stage is a proportional bar relative to the first.
const FunnelStrip = ({ stages }: { stages: { label: string; value: number }[] }) => {
  const C = useEmployeeHubColors();
  const max = Math.max(...stages.map((s) => s.value), 1);
  const summary = stages.map((s) => `${s.label}: ${s.value.toLocaleString()}`).join(", ");
  return (
    <Card sx={{ backgroundColor: C.surface, border: `1px solid ${C.border}`, borderRadius: "8px" }}>
      <CardContent sx={{ p: "16px 20px !important" }}>
        <Box role="img" aria-label={`Stage breakdown: ${summary}`} sx={{ display: "flex", alignItems: "stretch", flexWrap: { xs: "wrap", sm: "nowrap" }, rowGap: 2, columnGap: { xs: 2, sm: 0 } }}>
          {stages.map((stage, i) => {
            const pct = max ? Math.round((stage.value / max) * 100) : 0;
            return (
              <Fragment key={stage.label}>
                <Box sx={{ flex: { xs: "1 1 40%", sm: 1 }, minWidth: 0 }}>
                  <Typography sx={{ fontSize: "10px", color: C.muted, textTransform: "uppercase", letterSpacing: "0.06em", fontFamily: "monospace", mb: 1 }}>
                    {stage.label}
                  </Typography>
                  <Box sx={{ display: "flex", alignItems: "baseline", gap: 0.75, mb: 0.75 }}>
                    <Typography sx={{ fontSize: "22px", fontWeight: 700, fontFamily: "monospace", color: C.text, lineHeight: 1 }}>
                      {stage.value.toLocaleString()}
                    </Typography>
                    {i > 0 && (
                      <Typography sx={{ fontSize: "11px", fontWeight: 600, fontFamily: "monospace", color: C.muted, lineHeight: 1 }}>
                        {pct}% of {stages[0].label.toLowerCase()}
                      </Typography>
                    )}
                  </Box>
                  <Box sx={{ height: 8, borderRadius: 4, backgroundColor: C.hover, overflow: "hidden" }}>
                    <Box sx={{
                      width: `${pct}%`, height: "100%", borderRadius: 4, backgroundColor: i === 0 ? C.dim : C.orange,
                      transition: "width 0.3s", "@media (prefers-reduced-motion: reduce)": { transition: "none" },
                    }} />
                  </Box>
                </Box>
                {i < stages.length - 1 && (
                  <Box sx={{ display: { xs: "none", sm: "flex" }, alignItems: "center", px: 2, color: C.dim, pb: 1.25 }} aria-hidden="true">
                    <ArrowForwardIcon sx={{ fontSize: 16 }} />
                  </Box>
                )}
              </Fragment>
            );
          })}
        </Box>
      </CardContent>
    </Card>
  );
};

type SortDir = "asc" | "desc";
function SortableHeaderCell({ label, active, dir, align = "left", onClick }: { label: string; active: boolean; dir: SortDir; align?: "left" | "right"; onClick: () => void }) {
  const C = useEmployeeHubColors();
  return (
    <Box
      component="th"
      scope="col"
      aria-sort={active ? (dir === "asc" ? "ascending" : "descending") : "none"}
      tabIndex={0}
      aria-label={`Sort by ${label}`}
      onClick={onClick}
      onKeyDown={(e) => { if (e.key === "Enter" || e.key === " ") { e.preventDefault(); onClick(); } }}
      sx={{
        textAlign: align, py: 1, px: 1.5, cursor: "pointer", userSelect: "none", fontSize: "10px", color: active ? C.orange : C.muted,
        textTransform: "uppercase", letterSpacing: "0.06em", fontFamily: "monospace", borderBottom: `1px solid ${C.border}`, whiteSpace: "nowrap",
        backgroundColor: C.surface, position: "sticky", top: 0, "&:hover": { color: C.orange },
        "&:focus-visible": { outline: `2px solid ${C.orange}`, outlineOffset: "-2px" },
      }}
    >
      <Box sx={{ display: "inline-flex", alignItems: "center", gap: 0.4, justifyContent: align === "right" ? "flex-end" : "flex-start", width: "100%" }}>
        {label}
        {active ? (dir === "asc" ? <KeyboardArrowUpIcon sx={{ fontSize: 13 }} /> : <KeyboardArrowDownIcon sx={{ fontSize: 13 }} />) : <UnfoldMoreIcon sx={{ fontSize: 13, opacity: 0.35 }} />}
      </Box>
    </Box>
  );
}

const GROUP_PALETTE_KEYS = ["orange", "teal", "blue", "purple", "yellow"] as const;

// Employees: one column per real employment type (Permanent, Probation,
// Consultancy, ...) per team. Interns: Active/Ended per business unit.
const GroupBreakdown = ({ rows, kind }: { rows: any[]; kind: ViewKind }) => {
  const C = useEmployeeHubColors();
  const [sortKey, setSortKey] = useState<string>("total");
  const [sortDir, setSortDir] = useState<SortDir>("desc");

  const { data, columns } = useMemo(() => {
    const columnKeys = kind === "employees" ? employmentTypesIn(rows as EmployeeRow[]) : ["Active", "Ended"];
    const pctKey = "Active";
    const map: Record<string, { group: string; total: number; values: Record<string, number> }> = {};
    rows.forEach((r: any) => {
      const group = canonicalGroupKey(kind === "employees" ? r.team : r.bu) || "Unspecified";
      if (!map[group]) map[group] = { group, total: 0, values: {} };
      map[group].total += 1;
      const col = kind === "employees" ? ((r as EmployeeRow).employmentType || "Unspecified") : (isActiveStatus(r) ? "Active" : "Ended");
      map[group].values[col] = (map[group].values[col] || 0) + 1;
    });
    return {
      columns: columnKeys.map((key) => ({
        key,
        color: kind === "employees"
          ? (EMPLOYMENT_TYPE_COLOR_KEYS[key] ? C[EMPLOYMENT_TYPE_COLOR_KEYS[key]] : C.muted)
          : (key === "Active" ? C.teal : C.red),
      })),
      data: Object.values(map).map((d) => ({
        ...d,
        pct: d.total ? Math.round(((d.values[pctKey] || 0) / d.total) * 100) : 0,
      })),
    };
  }, [rows, kind, C]);

  // Each group's color is assigned by rank (largest group first, by total
  // headcount) rather than a name hash, so the biggest group always lands on
  // brand orange. Ranked by total specifically (not the current sort), so
  // colors stay stable as the table is re-sorted.
  const groupColors = useMemo(() => {
    const byTotal = [...data].sort((a, b) => b.total - a.total);
    const map = new Map<string, string>();
    byTotal.forEach((d, i) => map.set(d.group, C[GROUP_PALETTE_KEYS[i % GROUP_PALETTE_KEYS.length]]));
    return map;
  }, [data, C]);

  const sortValue = (d: (typeof data)[number], key: string): string | number =>
    key === "group" ? d.group : key === "total" ? d.total : key === "pct" ? d.pct : (d.values[key] || 0);

  const sorted = useMemo(() => {
    const copy = [...data];
    copy.sort((a, b) => {
      const av = sortValue(a, sortKey), bv = sortValue(b, sortKey);
      const cmp = typeof av === "string" ? av.localeCompare(bv as string) : (av as number) - (bv as number);
      return sortDir === "asc" ? cmp : -cmp;
    });
    return copy;
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [data, sortKey, sortDir]);

  const toggleSort = (key: string) => {
    if (sortKey === key) setSortDir((d) => (d === "asc" ? "desc" : "asc"));
    else { setSortKey(key); setSortDir("desc"); }
  };

  if (!data.length) return <SectionCard title="Breakdown" icon={TableChartIcon}><EmptyState /></SectionCard>;

  const groupLabel = kind === "interns" ? "Business Unit" : "Team";

  return (
    <>
      <Card sx={{ backgroundColor: C.surface, border: `1px solid ${C.border}`, borderRadius: "10px", overflow: "hidden" }}>
        <Box sx={{ overflowX: "auto" }}>
          <Box component="table" sx={{ width: "100%", borderCollapse: "collapse", fontSize: "12.5px" }}>
            <Box component="thead">
              <Box component="tr">
                <SortableHeaderCell label={groupLabel} active={sortKey === "group"} dir={sortDir} onClick={() => toggleSort("group")} />
                <SortableHeaderCell label="Total" active={sortKey === "total"} dir={sortDir} align="right" onClick={() => toggleSort("total")} />
                {columns.map((col) => (
                  <SortableHeaderCell key={col.key} label={col.key} active={sortKey === col.key} dir={sortDir} align="right" onClick={() => toggleSort(col.key)} />
                ))}
                {kind === "interns" && (
                  <>
                    <SortableHeaderCell label="% Active" active={sortKey === "pct"} dir={sortDir} align="right" onClick={() => toggleSort("pct")} />
                    <Box component="th" sx={{ py: 1, px: 1.5, borderBottom: `1px solid ${C.border}`, width: "20%", backgroundColor: C.surface, position: "sticky", top: 0 }} />
                  </>
                )}
              </Box>
            </Box>
            <Box component="tbody">
              {sorted.map((d) => (
                <Box component="tr" key={d.group} sx={{ "&:hover": { backgroundColor: C.hover } }}>
                  <Box component="td" sx={{ py: 1, pl: 1.5, pr: 1.5, color: C.text, fontWeight: 600, borderBottom: `1px solid ${C.border}`, borderLeft: `3px solid ${groupColors.get(d.group)}` }}>{d.group}</Box>
                  <Box component="td" sx={{ py: 1, px: 1.5, textAlign: "right", fontFamily: "monospace", color: C.text, borderBottom: `1px solid ${C.border}` }}>{d.total}</Box>
                  {columns.map((col) => (
                    <Box key={col.key} component="td" sx={{ py: 1, px: 1.5, textAlign: "right", fontFamily: "monospace", color: d.values[col.key] ? col.color : C.dim, borderBottom: `1px solid ${C.border}` }}>
                      {d.values[col.key] || 0}
                    </Box>
                  ))}
                  {kind === "interns" && (
                    <>
                      <Box component="td" sx={{ py: 1, px: 1.5, textAlign: "right", fontFamily: "monospace", color: C.muted, borderBottom: `1px solid ${C.border}` }}>{d.pct}%</Box>
                      <Box component="td" sx={{ py: 1, px: 1.5, borderBottom: `1px solid ${C.border}` }}>
                        <Box sx={{ height: 6, borderRadius: 3, backgroundColor: C.hover, overflow: "hidden" }}>
                          <Box sx={{ width: `${d.pct}%`, height: "100%", backgroundColor: C.orange, borderRadius: 3 }} />
                        </Box>
                      </Box>
                    </>
                  )}
                </Box>
              ))}
            </Box>
          </Box>
        </Box>
      </Card>
    </>
  );
};

export default function EmployeeHubDashboard() {
  const navigate = useNavigate();
  const location = useLocation();
  const C = useEmployeeHubColors();
  const isPhone = useMediaQuery(useTheme().breakpoints.down("sm"));
  const toggleSx = (active: boolean) => active
    ? { fontSize: "10px", px: 1.5, py: 0.4, backgroundColor: `${C.orange} !important`, color: "#FFFFFF !important", borderColor: `${C.orange} !important` }
    : { fontSize: "10px", px: 1.5, py: 0.4, borderColor: C.border, color: C.muted, "&:hover": { borderColor: C.dim, color: C.text } };

  // Driven by which sidebar sub-item (/employee-hub/employees vs
  // /employee-hub/interns) is active rather than local state, so the
  // two views are real, separately-navigable routes - matching how
  // Employees' All/My Team sub-items work - instead of an in-page toggle.
  const view: ViewKind = location.pathname === "/employee-hub/interns" ? "interns" : "employees";
  const [subTab, setSubTab] = useState<"overview" | "scorecard" | "roles" | "demographics" | "trends" | "explore">("overview");
  // Interns only have Overview + Explore; Permanent has no Explore tab.
  useEffect(() => {
    const valid = view === "interns" ? ["overview", "explore"] : ["overview", "scorecard", "roles", "demographics", "trends", "explore"];
    if (!valid.includes(subTab)) setSubTab("overview");
  }, [view, subTab]);

  const {
    interns, loading: internsLoading, refetch: refetchInterns,
    employees, leavers, employeesLoading, refetchEmployees, employeesIsLive,
  } = useEmployeeHub();
  useEmployeeHubBootstrap();
  const [date, setDate] = useState(new Date());
  const [timeRange, setTimeRange] = useState("1Y");
  const [detailLevel, setDetailLevel] = useState("monthly");

  const loading = internsLoading || employeesLoading;
  const refetch = () => { refetchInterns(); refetchEmployees(); };

  // No page-level search/filter anymore - every section below reflects the
  // full roster for whichever view is selected.
  const cleanEmployees = useMemo(() => (employees || []).filter((e) => normalize(e.name)), [employees]);
  const cleanLeavers = useMemo(() => (leavers || []).filter((e) => normalize(e.name)), [leavers]);
  const employeesByEmail = useMemo(() => buildEmailLookup(cleanEmployees), [cleanEmployees]);
  // Everyone who has held a non-intern role - current staff plus leavers -
  // so historical headcount and departures can be reconstructed per period.
  const everyEmployee = useMemo(() => [...cleanEmployees, ...cleanLeavers], [cleanEmployees, cleanLeavers]);
  // Anyone whose final day of employment has passed: "Left", plus any
  // "Marked leaver" the scheduler hasn't transitioned yet.
  const departedEmployees = useMemo(() => everyEmployee.filter((e) => departureDate(e)), [everyEmployee]);
  // ---- Permanent > Explore filters ----
  const empFilterFields = useMemo(() => ([
    { key: "bu", label: "Business Unit", get: (e: EmployeeRow) => canonicalGroupKey(e.bu) || "Unspecified" },
    { key: "team", label: "Team", get: (e: EmployeeRow) => canonicalGroupKey(e.team) || "Unspecified" },
    { key: "type", label: "Employment Type", get: (e: EmployeeRow) => e.employmentType || "Unspecified" },
    { key: "band", label: "Job Band", get: (e: EmployeeRow) => tierForJobBand(e.jobBand) },
    { key: "designation", label: "Job Title", get: (e: EmployeeRow) => normalize(e.designation) || "Unspecified" },
    { key: "gender", label: "Gender", get: (e: EmployeeRow) => genderLabel(e.gender) },
    { key: "location", label: "Location", get: (e: EmployeeRow) => normalize(e.location) || "Unspecified" },
    { key: "lead", label: "Lead", get: (e: EmployeeRow) => normalize(resolveNameByEmail(e.reportingManager, employeesByEmail)) || "Unassigned" },
    { key: "status", label: "Status", get: (e: EmployeeRow) => e.status || "Unknown" },
    { key: "tenure", label: "Years at Company", get: (e: EmployeeRow) => { const j = parseDate(e.joinDate); return j ? tenureGroup(yearsBetween(j, new Date())) : "Unknown"; } },
    { key: "joinYear", label: "Year Joined", get: (e: EmployeeRow) => String(parseDate(e.joinDate)?.getFullYear() || "Unknown") },
  ]), [employeesByEmail]);
  const [empFilters, setEmpFilters] = useState<Record<string, string[]>>({});
  const [empJoinedFrom, setEmpJoinedFrom] = useState("");
  const [empJoinedTo, setEmpJoinedTo] = useState("");
  const empFilterOptions = useMemo(() => {
    const out: Record<string, { name: string; value: number }[]> = {};
    empFilterFields.forEach((f) => {
      const opts = countBy(cleanEmployees, f.get);
      const order = f.key === "band" ? JOB_BAND_ORDER_JUNIOR_FIRST : f.key === "tenure" ? (TENURE_GROUPS as readonly string[]) : null;
      out[f.key] = order ? opts.sort((a, b) => order.indexOf(a.name) - order.indexOf(b.name))
        : f.key === "joinYear" ? opts.sort((a, b) => b.name.localeCompare(a.name)) : opts;
    });
    return out;
  }, [empFilterFields, cleanEmployees]);
  const filteredEmployees = useMemo(() => {
    const from = empJoinedFrom ? parseDate(empJoinedFrom) : null;
    const to = empJoinedTo ? parseDate(empJoinedTo) : null;
    return cleanEmployees.filter((e) => {
      for (const f of empFilterFields) {
        const sel = empFilters[f.key];
        if (sel && sel.length && !sel.includes(normalize(f.get(e)) || "Unknown")) return false;
      }
      if (from || to) {
        const j = parseDate(e.joinDate);
        if (!j || (from && j < from) || (to && j > to)) return false;
      }
      return true;
    });
  }, [cleanEmployees, empFilterFields, empFilters, empJoinedFrom, empJoinedTo]);
  const clearEmpFilters = () => { setEmpFilters({}); setEmpJoinedFrom(""); setEmpJoinedTo(""); };
  const exploreEmp = useMemo(() => {
    return {
      stats: (() => {
        const women = filteredEmployees.filter((e) => genderLabel(e.gender) === "Female").length;
        return {
          women,
          men: filteredEmployees.filter((e) => genderLabel(e.gender) === "Male").length,
          probation: filteredEmployees.filter((e) => e.employmentType === "Probation").length,
          leaving: filteredEmployees.filter((e) => e.status === EmployeeStatus.MarkedLeaver).length,
          teams: new Set(filteredEmployees.map((e) => canonicalGroupKey(e.team))).size,
        };
      })(),
    };
  }, [filteredEmployees]);
  const markedLeaversEmp = useMemo(() => cleanEmployees.filter((e) => e.status === EmployeeStatus.MarkedLeaver), [cleanEmployees]);

  const cleanInterns = useMemo(() => (interns || []).filter((i) => normalize(i.name)), [interns]);
  const activeInterns = useMemo(() => cleanInterns.filter(isActiveStatus), [cleanInterns]);

  // ---- Interns > Explore filters ----
  const internFilterFields = useMemo(() => ([
    { key: "bu", label: "Business Unit", get: (i: InternRow) => canonicalGroupKey(i.bu) || "Unspecified" },
    { key: "team", label: "Team", get: (i: InternRow) => canonicalGroupKey(i.team) || "Unspecified" },
    { key: "university", label: "University", get: (i: InternRow) => normalize(i.university) || "Unspecified" },
    { key: "mentor", label: "Mentor", get: (i: InternRow) => normalize(resolveNameByEmail(i.mentorEmail, employeesByEmail)) || "Unassigned" },
    { key: "status", label: "Status", get: (i: InternRow) => getStatusDisplay(i.status).label || "Unknown" },
    { key: "gender", label: "Gender", get: (i: InternRow) => genderLabel(i.gender) },
    { key: "joinYear", label: "Year Joined", get: (i: InternRow) => String(parseDate(i.joinedDate)?.getFullYear() || "Unknown") },
  ]), [employeesByEmail]);
  const [internFilters, setInternFilters] = useState<Record<string, string[]>>({});
  const [internJoinedFrom, setInternJoinedFrom] = useState("");
  const [internJoinedTo, setInternJoinedTo] = useState("");
  const internFilterOptions = useMemo(() => {
    const out: Record<string, { name: string; value: number }[]> = {};
    internFilterFields.forEach((f) => {
      const opts = countBy(cleanInterns, f.get);
      out[f.key] = f.key === "joinYear" ? opts.sort((a, b) => b.name.localeCompare(a.name)) : opts;
    });
    return out;
  }, [internFilterFields, cleanInterns]);
  const filteredInterns = useMemo(() => {
    const from = internJoinedFrom ? parseDate(internJoinedFrom) : null;
    const to = internJoinedTo ? parseDate(internJoinedTo) : null;
    return cleanInterns.filter((i) => {
      for (const f of internFilterFields) {
        const sel = internFilters[f.key];
        if (sel && sel.length && !sel.includes(normalize(f.get(i)) || "Unknown")) return false;
      }
      if (from || to) {
        const j = parseDate(i.joinedDate);
        if (!j || (from && j < from) || (to && j > to)) return false;
      }
      return true;
    });
  }, [cleanInterns, internFilterFields, internFilters, internJoinedFrom, internJoinedTo]);
  const clearInternFilters = () => { setInternFilters({}); setInternJoinedFrom(""); setInternJoinedTo(""); };
  const internStatusMix = useMemo(() => {
    const count = (key: string) => filteredInterns.filter((i) => getStatusDisplay(i.status).colorKey === key).length;
    return [
      { name: "Active", value: count("active"), color: C.teal },
      { name: "Not Started", value: count("not_started"), color: C.yellow },
      { name: "Ended", value: count("ended"), color: C.red },
    ].filter((d) => d.value > 0);
  }, [filteredInterns, C]);
  const exploreIntern = useMemo(() => {
    return {
      universityCount: new Set(filteredInterns.map((i) => normalize(i.university)).filter(Boolean)).size,
      mentorCount: new Set(filteredInterns.map((i) => emailKey(i.mentorEmail)).filter(Boolean)).size,
    };
  }, [filteredInterns]);

  // Month summary for the selected date's month, defined as on HR's Intern Count
  // Summary sheet. The KPI cards and the lists they open share these arrays.
  const internMonth = useMemo(() => summariseInternMonth(cleanInterns, date), [cleanInterns, date]);

  const empDateStats = useMemo(() => {
    let newHires = 0, hiredThisYear = 0, hiredThisQuarter = 0;
    // dayjs clamps to the month's last day (31 May - 3 months = 28/29 Feb),
    // where Date.setMonth would overflow into March.
    const quarterStart = dayjs(startOfDay(date)).subtract(3, "month").toDate();
    cleanEmployees.forEach((e) => {
      const j = parseDate(e.joinDate);
      if (!j) return;
      if (isSameMonthAndYear(j, date)) newHires++;
      if (j.getFullYear() === date.getFullYear()) hiredThisYear++;
      if (j >= quarterStart && j <= date) hiredThisQuarter++;
    });
    return { newHires, hiredThisYear, hiredThisQuarter };
  }, [cleanEmployees, date]);

  // Only employment type "Probation" - Permanent staff also carry a
  // (historical) probation_end_date, which says nothing about confirmation.
  const onProbationEmp = useMemo(() => cleanEmployees.filter((e) => e.employmentType === "Probation"), [cleanEmployees]);
  // Year to date (1 Jan to the selected date).
  const leftYtdEmp = useMemo(() => {
    const from = new Date(date.getFullYear(), 0, 1);
    return departedEmployees.filter((e) => { const f = departureDate(e) as Date; return f >= from && f <= date; });
  }, [departedEmployees, date]);
  const permanentEmp = useMemo(() => cleanEmployees.filter((e) => e.employmentType === "Permanent"), [cleanEmployees]);
  const consultantsEmp = useMemo(() => cleanEmployees.filter((e) => /consult/i.test(e.employmentType)), [cleanEmployees]);


  const totalActiveListInterns = activeInterns;



  const calendarJoinDates = useMemo(() => {
    const dates = view === "interns" ? cleanInterns.map((i) => i.joinedDate) : cleanEmployees.map((e) => e.joinDate);
    return new Set(dates.map((d) => dateKey(parseDate(d))).filter(Boolean) as string[]);
  }, [view, cleanInterns, cleanEmployees]);

  // Interns: every internship end date, past or upcoming, so the month being
  // viewed shows who is finishing in it.
  const calendarEndDates = useMemo(() => {
    if (view !== "interns") return new Set(departedEmployees.map((e) => dateKey(departureDate(e))).filter(Boolean) as string[]);
    const today = startOfDay(new Date());
    return new Set(cleanInterns
      .filter((i) => !leftBeforeEndDate(i, today))
      .map((i) => dateKey(parseDate(i.endDate)))
      .filter(Boolean) as string[]);
  }, [view, cleanInterns, departedEmployees]);

  const [calendarAnchor, setCalendarAnchor] = useState<HTMLElement | null>(null);
  const [personModal, setPersonModal] = useState<PersonModal | null>(null);
  const [modalSearch, setModalSearch] = useState("");
  useEffect(() => { setModalSearch(""); }, [personModal]);

  const handleCalendarSelect = (d?: Date) => {
    if (!d) return;
    setDate(d);
    const sameDay = (a: Date | null) => !!a && a.getFullYear() === d.getFullYear() && a.getMonth() === d.getMonth() && a.getDate() === d.getDate();
    const dateLabel = format(d, "d MMM yyyy");
    if (view === "interns") {
      const joinedRows = cleanInterns.filter((i) => sameDay(parseDate(i.joinedDate)));
      const today = startOfDay(new Date());
      const endedRows = cleanInterns.filter((i) => !leftBeforeEndDate(i, today) && sameDay(parseDate(i.endDate)));
      const endVerb = d >= today ? "ending" : "ended";
      if (joinedRows.length && endedRows.length) {
        setPersonModal({ title: "Activity on This Day", subtitle: `${dateLabel} · ${joinedRows.length} joined, ${endedRows.length} ${endVerb}`, rows: [...joinedRows, ...endedRows], kind: "interns" });
      } else if (joinedRows.length) {
        setPersonModal({ title: "Joined on This Day", subtitle: dateLabel, rows: joinedRows, kind: "interns" });
      } else if (endedRows.length) {
        setPersonModal({ title: d >= today ? "Ending on This Day" : "Ended on This Day", subtitle: dateLabel, rows: endedRows, kind: "interns" });
      }
    } else {
      const joinedRows = everyEmployee.filter((e) => sameDay(parseDate(e.joinDate)));
      const leftRows = departedEmployees.filter((e) => sameDay(departureDate(e)));
      if (joinedRows.length) {
        setPersonModal({ title: "Joined on This Day", subtitle: dateLabel, rows: joinedRows, kind: "employees" });
      } else if (leftRows.length) {
        setPersonModal({ title: "Left on This Day", subtitle: dateLabel, rows: leftRows, kind: "employees" });
      }
    }
  };

  const trendData = useMemo(() => {
    const now = new Date(date);
    const periods: any[] = [];
    const monthsBack = timeRange === "3M" ? 3 : timeRange === "6M" ? 6 : 12;
    if (detailLevel === "daily") {
      for (let i = 89; i >= 0; i--) {
        const d = new Date(now); d.setDate(d.getDate() - i);
        periods.push({ label: format(d, "MMM d"), start: new Date(d.getFullYear(), d.getMonth(), d.getDate()), end: new Date(d.getFullYear(), d.getMonth(), d.getDate(), 23, 59, 59), active: 0, intake: 0, resignations: 0 });
      }
    } else {
      for (let i = monthsBack - 1; i >= 0; i--) {
        const d = new Date(now.getFullYear(), now.getMonth() - i, 1);
        periods.push({ label: format(d, "MMM yy"), start: d, end: new Date(d.getFullYear(), d.getMonth() + 1, 0, 23, 59, 59), active: 0, intake: 0, resignations: 0 });
      }
    }
    periods.forEach((p) => {
      cleanInterns.forEach((intern) => {
        const j = parseDate(intern.joinedDate);
        const e = parseDate(intern.endDate);
        // No end date: active only while the intern is not Ended. Old records
        // without one are all Left, and would otherwise count as active forever.
        if (j && j <= p.end && (e ? e >= p.start : !internHasEnded(intern))) p.active++;
        if (j && j >= p.start && j <= p.end) p.intake++;
        if (internHasEnded(intern) && e && e >= p.start && e <= p.end) p.resignations++;
      });
    });
    return periods;
  }, [cleanInterns, date, detailLevel, timeRange]);

  const trendDataEmp = useMemo(() => {
    const now = new Date(date);
    const periods: any[] = [];
    const monthsBack = timeRange === "3M" ? 3 : timeRange === "6M" ? 6 : 12;
    if (detailLevel === "daily") {
      for (let i = 89; i >= 0; i--) {
        const d = new Date(now); d.setDate(d.getDate() - i);
        periods.push({ label: format(d, "MMM d"), start: new Date(d.getFullYear(), d.getMonth(), d.getDate()), end: new Date(d.getFullYear(), d.getMonth(), d.getDate(), 23, 59, 59), active: 0, intake: 0, resignations: 0 });
      }
    } else {
      for (let i = monthsBack - 1; i >= 0; i--) {
        const d = new Date(now.getFullYear(), now.getMonth() - i, 1);
        periods.push({ label: format(d, "MMM yy"), start: d, end: new Date(d.getFullYear(), d.getMonth() + 1, 0, 23, 59, 59), active: 0, intake: 0, resignations: 0 });
      }
    }
    periods.forEach((p) => {
      everyEmployee.forEach((emp) => {
        const j = parseDate(emp.joinDate);
        if (!j) return;
        const f = departureDate(emp);
        if (!hasUnknownDeparture(emp) && j <= p.end && (!f || f >= p.start)) p.active++;
        if (j >= p.start && j <= p.end) p.intake++;
        if (f && f >= p.start && f <= p.end) p.resignations++;
      });
    });
    return periods;
  }, [everyEmployee, date, detailLevel, timeRange]);



  const teamData = useMemo(() => countBy(activeInterns, (i) => canonicalGroupKey(i.team)), [activeInterns]);
  const universityData = useMemo(() => countBy(activeInterns, (i) => i.university), [activeInterns]);
  const mentorData = useMemo(() => countByPerson(activeInterns, (i) => i.mentorEmail, employeesByEmail), [activeInterns, employeesByEmail]);

  // Every distinct team, for the job-band pyramid's team selector - not
  // capped to a top-N, since a team with a small
  // headcount should still be pickable here.
  const allTeamsEmp = useMemo(() => countBy(cleanEmployees, (e) => canonicalGroupKey(e.team)), [cleanEmployees]);
  const [pyramidTeam, setPyramidTeam] = useState(ALL_TEAMS);
  const pyramidEmployees = useMemo(
    () => pyramidTeam === ALL_TEAMS ? cleanEmployees : cleanEmployees.filter((e) => canonicalGroupKey(e.team) === pyramidTeam),
    [cleanEmployees, pyramidTeam]
  );
  const jobBandPyramidData = useMemo(() => {
    const counts: Record<string, number> = {};
    pyramidEmployees.forEach((e) => { const t = tierForJobBand(e.jobBand); counts[t] = (counts[t] || 0) + 1; });
    return JOB_BAND_TIERS.map((t) => ({ name: t.key, value: counts[t.key] || 0 }));
  }, [pyramidEmployees]);
  const pyramidNoBandCount = useMemo(
    () => pyramidEmployees.filter((e) => tierForJobBand(e.jobBand) === NO_BAND_TIER).length,
    [pyramidEmployees]
  );
  // Team-wise job band split, largest teams first (all teams; the table scrolls).
  const jobBandByTeamEmp = useMemo(() => {
    const map: Record<string, Record<string, number> & { name: string; total: number }> = {};
    cleanEmployees.forEach((e) => {
      const team = canonicalGroupKey(e.team) || "Unspecified";
      if (!map[team]) map[team] = { name: team, total: 0 } as any;
      const tier = tierForJobBand(e.jobBand);
      map[team][tier] = (map[team][tier] || 0) + 1;
      map[team].total += 1;
    });
    return Object.values(map).sort((a, b) => b.total - a.total);
  }, [cleanEmployees]);
  // Junior -> senior, then No Band; only columns that have anyone in them.
  const jobBandColumns = useMemo(
    () => [...[...JOB_BAND_TIERS].reverse().map((t) => t.key as string), NO_BAND_TIER]
      .filter((col) => jobBandByTeamEmp.some((r) => (r as any)[col])),
    [jobBandByTeamEmp]
  );
  // Company-wide row for the top of the table - same columns, all employees.
  const jobBandAllRow = useMemo(() => {
    const row: Record<string, number> = {};
    jobBandByTeamEmp.forEach((r) => jobBandColumns.forEach((col) => { row[col] = (row[col] || 0) + ((r as any)[col] || 0); }));
    return { counts: row, total: cleanEmployees.length, max: Math.max(1, ...Object.values(row)) };
  }, [jobBandByTeamEmp, jobBandColumns, cleanEmployees]);
  const jobBandCellMax = useMemo(
    () => Math.max(1, ...jobBandByTeamEmp.flatMap((r) => jobBandColumns.map((col) => (r as any)[col] || 0))),
    [jobBandByTeamEmp, jobBandColumns]
  );

  // Leavers within the selected trend range (same window as the charts).
  const leaversInRangeEmp = useMemo(() => {
    const start = trendDataEmp[0]?.start as Date | undefined;
    const end = trendDataEmp[trendDataEmp.length - 1]?.end as Date | undefined;
    if (!start || !end) return [];
    return departedEmployees.filter((e) => { const f = departureDate(e) as Date; return f >= start && f <= end; });
  }, [departedEmployees, trendDataEmp]);
  const hiresInRangeEmp = useMemo(() => {
    const start = trendDataEmp[0]?.start as Date | undefined;
    const end = trendDataEmp[trendDataEmp.length - 1]?.end as Date | undefined;
    if (!start || !end) return [];
    return everyEmployee.filter((e) => { const j = parseDate(e.joinDate); return j && j >= start && j <= end; });
  }, [everyEmployee, trendDataEmp]);
  const hiresByTeamEmp = useMemo(() => countBy(hiresInRangeEmp, (e) => canonicalGroupKey(e.team)).slice(0, 8), [hiresInRangeEmp]);
  // How long leavers in the selected range had been with the company.
  const exitTenureEmp = useMemo(() => {
    const buckets: Record<string, number> = { "<1 yr": 0, "1-2 yrs": 0, "2-5 yrs": 0, "5+ yrs": 0 };
    leaversInRangeEmp.forEach((e) => {
      const j = parseDate(e.joinDate);
      const f = departureDate(e);
      if (!j || !f) return;
      const years = (f.getTime() - j.getTime()) / (365.25 * 24 * 3600 * 1000);
      buckets[years < 1 ? "<1 yr" : years < 2 ? "1-2 yrs" : years < 5 ? "2-5 yrs" : "5+ yrs"]++;
    });
    return Object.entries(buckets).map(([name, value]) => ({ name, value }));
  }, [leaversInRangeEmp]);
  // Headcount on 31 Dec of each of the last 5 years, plus today.
  const yearlyHeadcountEmp = useMemo(() => {
    const today = new Date();
    const points = [];
    for (let y = today.getFullYear() - 5; y < today.getFullYear(); y++) points.push({ label: `Dec ${y}`, at: new Date(y, 11, 31) });
    points.push({ label: "Today", at: today });
    return points.map(({ label, at }) => ({
      label,
      value: everyEmployee.filter((e) => {
        if (hasUnknownDeparture(e)) return false;
        const j = parseDate(e.joinDate);
        const f = departureDate(e);
        return j && j <= at && (!f || f > at);
      }).length,
    }));
  }, [everyEmployee]);
  const leaversByTeamEmp = useMemo(
    () => countBy(leaversInRangeEmp, (e) => canonicalGroupKey(e.team)).slice(0, 8),
    [leaversInRangeEmp]
  );



  const genderByGroup = (rows: EmployeeRow[], getKey: (e: EmployeeRow) => string) => {
    const map: Record<string, { name: string; total: number; male: number; female: number }> = {};
    rows.forEach((e) => {
      const key = normalize(getKey(e)) || "Unspecified";
      if (!map[key]) map[key] = { name: key, total: 0, male: 0, female: 0 };
      map[key].total++;
      const g = normalize(e.gender).toLowerCase();
      if (g.startsWith("m")) map[key].male++; else if (g.startsWith("f")) map[key].female++;
    });
    const list = Object.values(map)
      .map((d) => ({ ...d, pctMale: d.total ? (d.male / d.total) * 100 : 0, pctFemale: d.total ? (d.female / d.total) * 100 : 0 }))
      .sort((a, b) => b.total - a.total);
    const grand = list.reduce((acc, d) => ({ total: acc.total + d.total, male: acc.male + d.male, female: acc.female + d.female }), { total: 0, male: 0, female: 0 });
    return {
      rows: list,
      grand: { ...grand, pctMale: grand.total ? (grand.male / grand.total) * 100 : 0, pctFemale: grand.total ? (grand.female / grand.total) * 100 : 0 },
    };
  };

  const peopleEmp = useMemo(() => {
    const tenure: Record<string, { name: string; Male: number; Female: number }> = {};
    TENURE_GROUPS.forEach((g) => { tenure[g] = { name: g, Male: 0, Female: 0 }; });
    const bu: Record<string, { name: string; Male: number; Female: number; total: number }> = {};
    cleanEmployees.forEach((e) => {
      const g = genderLabel(e.gender);
      const key = canonicalGroupKey(e.bu) || "Unspecified";
      bu[key] ||= { name: key, Male: 0, Female: 0, total: 0 };
      bu[key].total++;
      if (g === "Male" || g === "Female") bu[key][g]++;
      const j = parseDate(e.joinDate);
      if (j && (g === "Male" || g === "Female")) tenure[tenureGroup(yearsBetween(j, new Date()))][g]++;
    });
    return {
      gender: countBy(cleanEmployees, (e) => genderLabel(e.gender)),
      location: countBy(cleanEmployees, (e) => e.location || "Unspecified").slice(0, 7),
      tenure: TENURE_GROUPS.map((g) => ({ name: g, value: tenure[g].Male + tenure[g].Female })),
      tenureByGender: TENURE_GROUPS.map((g) => tenure[g]),
      genderByBu: Object.values(bu).sort((a, b) => b.total - a.total).slice(0, 10),
    };
  }, [cleanEmployees]);

  const genderByTeamEmp = useMemo(() => genderByGroup(cleanEmployees, (e) => canonicalGroupKey(e.team)), [cleanEmployees]);
  const genderByLocationEmp = useMemo(() => genderByGroup(cleanEmployees, (e) => e.location), [cleanEmployees]);


  const handleExport = () => {
    // escapeFormulae stops a cell starting with =, +, - or @ from running as a
    // formula when the file is opened in a spreadsheet.
    const csv = view === "employees"
      ? Papa.unparse(cleanEmployees.map((e) => ({ Name: e.name, Team: e.team, BU: e.bu, Status: e.status, "Join Date": e.joinDate || "", "Employment Type": e.employmentType, "Job Band": e.jobBand ?? "", "Reporting Lead": e.reportingManager })), { escapeFormulae: true })
      : Papa.unparse(cleanInterns.map((i) => ({ Name: i.name, BU: i.bu, Team: i.team, Status: i.status, "Joined Date": i.joinedDate || "", "End Date": i.endDate || "", Mentor: i.mentorEmail })), { escapeFormulae: true });
    // Same download steps as EmployeeReportTable.handleExport: the link must be
    // in the page, and revoking the URL straight after click() can cancel the
    // download in Firefox and Safari.
    const url = URL.createObjectURL(new Blob([csv], { type: "text/csv;charset=utf-8;" }));
    const link = document.createElement("a");
    link.href = url;
    link.download = `wso2-${view}-${format(new Date(), "yyyy-MM-dd")}.csv`;
    document.body.appendChild(link);
    link.click();
    document.body.removeChild(link);
    setTimeout(() => URL.revokeObjectURL(url), 100);
  };

  const peakActive = Math.max(...trendData.map((d) => d.active), 0);
  const totalIntake = trendData.reduce((s, d) => s + d.intake, 0);
  const totalResign = trendData.reduce((s, d) => s + d.resignations, 0);

  const peakActiveEmp = Math.max(...trendDataEmp.map((d) => d.active), 0);
  const totalHiresEmp = trendDataEmp.reduce((s, d) => s + d.intake, 0);
  const totalLeftEmp = trendDataEmp.reduce((s, d) => s + d.resignations, 0);


  // ---- Explore tab data ----
  const lastTwelveMonths = useMemo(() => Array.from({ length: 12 }, (_, k) => {
    const start = new Date(date.getFullYear(), date.getMonth() - 11 + k, 1);
    return { name: format(start, "MMM yy"), start, end: new Date(start.getFullYear(), start.getMonth() + 1, 0, 23, 59, 59) };
  }), [date]);
  const joinedPerMonth = <T,>(rows: T[], getDate: (r: T) => unknown) => lastTwelveMonths.map((m) => ({
    name: m.name,
    value: rows.filter((r) => { const j = parseDate(getDate(r)); return j && j >= m.start && j <= m.end; }).length,
  }));
  const dimensionData = <T,>(rows: T[], field: { key: string; get: (r: T) => string }, order?: readonly string[]) => {
    const counts = countBy(rows, field.get);
    if (order) return counts.sort((a, b) => order.indexOf(a.name) - order.indexOf(b.name));
    if (field.key === "joinYear") return counts.sort((a, b) => b.name.localeCompare(a.name));
    return counts;
  };

  const exploreEmpView = useMemo(() => {
    const field = (key: string) => empFilterFields.find((f) => f.key === key)!;
    const dim = (key: string, title: string, icon: any, color: string, order?: readonly string[]): ExploreDimension => ({
      key, title, icon, color, filterKey: key, keepOrder: !!order || key === "joinYear" || key === "gender",
      data: dimensionData(filteredEmployees, field(key), order),
    });
    return {
      stats: [
        { label: "Women", value: exploreEmp.stats.women, color: C.purple },
        { label: "Men", value: exploreEmp.stats.men, color: C.blue },
        { label: "On probation", value: exploreEmp.stats.probation, color: C.yellow },
        { label: "Leaving soon", value: exploreEmp.stats.leaving, color: C.red },
      ],
      timeline: joinedPerMonth(filteredEmployees, (e) => e.joinDate),
      dimensions: [
        dim("bu", "Business Unit", AccountBalanceIcon, C.teal),
        dim("team", "Team", GroupsIcon, C.orange),
        dim("type", "Employment Type", LayersIcon, C.purple),
        dim("band", "Job Band", DeviceHubIcon, C.blue, JOB_BAND_ORDER_JUNIOR_FIRST),
        dim("location", "Location", PercentIcon, C.teal),
        dim("gender", "Gender", GroupsIcon, C.purple),
        dim("tenure", "Years at the Company", AccessTimeIcon, C.orange, TENURE_GROUPS),
        dim("lead", "Lead", HowToRegIcon, C.blue),
        dim("joinYear", "Year Joined", CalendarTodayIcon, C.teal),
      ],
    };
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [filteredEmployees, empFilterFields, exploreEmp, lastTwelveMonths, C]);

  const exploreInternView = useMemo(() => {
    const field = (key: string) => internFilterFields.find((f) => f.key === key)!;
    const dim = (key: string, title: string, icon: any, color: string, keepOrder = false): ExploreDimension => ({
      key, title, icon, color, filterKey: key, keepOrder: keepOrder || key === "joinYear",
      data: dimensionData(filteredInterns, field(key)),
    });
    return {
      stats: [
        { label: "Working now", value: internStatusMix.find((d) => d.name === "Active")?.value || 0, color: C.teal },
        { label: "Not started yet", value: internStatusMix.find((d) => d.name === "Not Started")?.value || 0, color: C.yellow },
        { label: "Finished", value: internStatusMix.find((d) => d.name === "Ended")?.value || 0, color: C.red },
        { label: "Universities", value: exploreIntern.universityCount, color: C.purple },
        { label: "Mentors", value: exploreIntern.mentorCount, color: C.yellow },
      ],
      timeline: joinedPerMonth(filteredInterns, (i) => i.joinedDate),
      dimensions: [
        dim("status", "Status", PieChartIcon, C.teal, true),
        dim("bu", "Business Unit", AccountBalanceIcon, C.teal),
        dim("team", "Team", GroupsIcon, C.orange),
        dim("university", "University", SchoolIcon, C.blue),
        dim("mentor", "Mentor", HowToRegIcon, C.orange),
        dim("gender", "Gender", GroupsIcon, C.purple, true),
        dim("joinYear", "Year Joined", CalendarTodayIcon, C.orange),
      ],
    };
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [filteredInterns, internFilterFields, internStatusMix, exploreIntern, lastTwelveMonths, C]);

  if (loading) {
    return (
      <Box sx={{ m: 3, display: "flex", flexDirection: "column", gap: 2 }}>
        <Skeleton variant="rectangular" sx={{ width: "100%", height: 90, borderRadius: 1 }} />
        <Skeleton variant="rectangular" sx={{ width: "100%", height: 320, borderRadius: 1 }} />
        <Skeleton variant="rectangular" sx={{ width: "100%", height: 220, borderRadius: 1 }} />
      </Box>
    );
  }

  return (
    <Box sx={{ p: { xs: "12px 4px", sm: "20px 24px" }, display: "flex", flexDirection: "column", gap: "16px", backgroundColor: C.bg, minHeight: "100%", borderTop: `2px solid ${C.orange}` }}>

      {/* Header */}
      <Box sx={{ display: "flex", alignItems: "center", justifyContent: "space-between", flexWrap: "wrap", gap: 1 }}>
        <Box sx={{ display: "flex", alignItems: "center", gap: 1 }}>
          <Box sx={{ width: 26, height: 26, borderRadius: "50%", backgroundColor: `${C.orange}1A`, display: "flex", alignItems: "center", justifyContent: "center" }}>
            <BarChartIcon sx={{ fontSize: 14, color: C.orange }} />
          </Box>
          <Typography sx={{ fontSize: "14px", fontWeight: 700, color: C.text, letterSpacing: "-0.01em" }}>
            {view === "interns" ? "Intern Dashboard" : "Employee Dashboard"}
          </Typography>
        </Box>
        <Box sx={{ display: "flex", flexDirection: "column", alignItems: "flex-end", gap: 0.25 }}>
          <Typography sx={{ fontSize: "9px", color: C.muted, textTransform: "uppercase", letterSpacing: "0.08em", fontFamily: "monospace" }}>
            Showing data for
          </Typography>
          <Button variant="outlined" size="small" startIcon={<CalendarTodayIcon sx={{ fontSize: 12 }} />}
            onClick={(e) => setCalendarAnchor(e.currentTarget)}
            sx={{ fontSize: "10.5px", minWidth: 0, px: 1, py: 0.3, borderColor: C.border, color: C.subtle, fontFamily: "monospace", "&:hover": { borderColor: C.orange, backgroundColor: `${C.orange}11` } }}>
            {format(date, "d MMM yy")}
          </Button>
          <Popover
            open={!!calendarAnchor}
            anchorEl={calendarAnchor}
            onClose={() => setCalendarAnchor(null)}
            anchorOrigin={{ vertical: "bottom", horizontal: "right" }}
            transformOrigin={{ vertical: "top", horizontal: "right" }}
            slotProps={{ paper: { sx: { mt: 0.5, p: 1.5, border: `1px solid ${C.border}`, backgroundColor: C.surface } } }}
          >
            <LocalizationProvider dateAdapter={AdapterDayjs}>
              <DateCalendar
                value={dayjs(date)}
                onChange={(d: dayjs.Dayjs | null, selectionState?: PickerSelectionState) => {
                  // Picking a year or month fires a "partial" change before the
                  // day view opens; only a picked day selects a date.
                  if (selectionState !== "finish") return;
                  handleCalendarSelect(d ? d.toDate() : undefined);
                  setCalendarAnchor(null);
                }}
                slots={{ day: CalendarDayCell as any }}
                slotProps={{ day: { joinDates: calendarJoinDates, endDates: calendarEndDates } as any }}
                sx={{ backgroundColor: C.surface, color: C.text }}
              />
            </LocalizationProvider>
            <Box sx={{ display: "flex", gap: 2, px: 0.5, pt: 1.5, borderTop: `1px solid ${C.border}`, mt: 1 }}>
              <Box sx={{ display: "flex", alignItems: "center", gap: 0.75 }}>
                <Box sx={{ width: 8, height: 8, borderRadius: "50%", backgroundColor: C.teal }} />
                <Typography sx={{ fontSize: "11px", color: C.muted }}>Joined</Typography>
              </Box>
              {view === "interns" && (
                <Box sx={{ display: "flex", alignItems: "center", gap: 0.75 }}>
                  <Box sx={{ width: 8, height: 8, borderRadius: "50%", backgroundColor: C.red }} />
                  <Typography sx={{ fontSize: "11px", color: C.muted }}>Ends</Typography>
                </Box>
              )}
            </Box>
            <Typography sx={{ fontSize: "10.5px", color: C.dim, px: 0.5, pt: 1 }}>
              Click a day with a dot to see who joined{view === "interns" ? " or finishes" : ""} that day.
            </Typography>
          </Popover>
        </Box>
      </Box>

      {!isToday(date) && (
        <Alert severity="info" sx={{ borderRadius: "8px" }}
          action={<Button color="inherit" size="small" onClick={() => setDate(new Date())}>Go to Today</Button>}>
          You are looking at data for {format(date, "d MMM yyyy")}, not today.
        </Alert>
      )}

      {view === "employees" && !employeesIsLive && (
        <Alert severity="warning" sx={{ borderRadius: "8px" }}
          action={<Button color="inherit" size="small" onClick={refetchEmployees}>Retry</Button>}>
          Employee data could not be loaded, so employee numbers and charts are empty.
        </Alert>
      )}

      {/* Funnel-style stage strip */}
      <FunnelStrip
        stages={view === "interns" ? [
          { label: "Total Interns", value: cleanInterns.length },
          { label: "Active", value: activeInterns.length },
          { label: "Joining This Month", value: internMonth.joiningThisMonth.length },
          { label: "Joining Next Month", value: internMonth.joiningNextMonth.length },
        ] : [
          { label: "Total Employees", value: cleanEmployees.length },
          { label: "Joined This Year", value: empDateStats.hiredThisYear },
          { label: "Joined in Last 3 Months", value: empDateStats.hiredThisQuarter },
          { label: "Joined This Month", value: empDateStats.newHires },
        ]}
      />

      {/* Sub-view tabs - pinned under the app header so they stay reachable while scrolling */}
      <Box sx={{ borderBottom: `1px solid ${C.border}`, position: "sticky", top: APP_HEADER_HEIGHT, zIndex: 5, backgroundColor: C.bg, height: SUB_TABS_HEIGHT, boxSizing: "border-box" }}>
        <Tabs
          value={subTab}
          onChange={(_, val) => setSubTab(val)}
          variant="scrollable" scrollButtons="auto" allowScrollButtonsMobile
          sx={{
            minHeight: 36,
            "& .MuiTab-root": { minHeight: 36, textTransform: "none", fontSize: "12.5px", fontWeight: 600, color: C.muted, gap: 0.75, flexDirection: "row" },
            "& .Mui-selected": { color: `${C.orange} !important` },
            "& .MuiTabs-indicator": { backgroundColor: C.orange, height: 2 },
          }}
        >
          <Tab value="overview" icon={<DashboardIcon sx={{ fontSize: 14 }} />} iconPosition="start" label="Overview" />
          {view === "interns" && <Tab value="explore" icon={<FilterListIcon sx={{ fontSize: 14 }} />} iconPosition="start" label="Explore" />}
          {view === "employees" && <Tab value="scorecard" icon={<TableChartIcon sx={{ fontSize: 14 }} />} iconPosition="start" label="Teams" />}
          {view === "employees" && <Tab value="roles" icon={<DeviceHubIcon sx={{ fontSize: 14 }} />} iconPosition="start" label="Job Bands" />}
          {view === "employees" && <Tab value="demographics" icon={<PieChartIcon sx={{ fontSize: 14 }} />} iconPosition="start" label="People" />}
          {view === "employees" && <Tab value="trends" icon={<TrendingUpIcon sx={{ fontSize: 14 }} />} iconPosition="start" label="Joiners & Leavers" />}
          {view === "employees" && <Tab value="explore" icon={<FilterListIcon sx={{ fontSize: 14 }} />} iconPosition="start" label="Explore" />}
        </Tabs>
      </Box>

      {subTab === "overview" && (
        <>
          {/* KPI Cards */}
          {view === "interns" ? (
            <Box sx={{ display: "grid", gridTemplateColumns: "repeat(auto-fit, minmax(150px, 1fr))", gap: 1.5 }}>
              <KPICard label="Current Interns" value={activeInterns.length} color={C.teal} icon={GroupsIcon}
                onClick={() => setPersonModal({ title: "Current Interns", subtitle: "Interns working now", rows: totalActiveListInterns, kind: "interns" })} />
              <KPICard label="Joining This Month" value={internMonth.joiningThisMonth.length} color={C.orange} icon={PersonAddIcon}
                onClick={() => setPersonModal({ title: "New Interns Joining This Month", subtitle: format(date, "MMMM yyyy"), rows: internMonth.joiningThisMonth, kind: "interns" })} />
              <KPICard label="Accumulated" value={internMonth.accumulated.length} subtext="carried over + joining" color={C.teal} icon={HowToRegIcon}
                onClick={() => setPersonModal({ title: "Accumulated Interns", subtitle: format(date, "MMMM yyyy"), rows: internMonth.accumulated, kind: "interns" })} />
              <KPICard label="Leaving This Month" value={internMonth.leavingThisMonth.length} color={C.orange} icon={LogoutIcon}
                onClick={() => setPersonModal({ title: "Interns Leaving This Month", subtitle: format(date, "MMMM yyyy"), rows: internMonth.leavingThisMonth, kind: "interns" })} />
              <KPICard label="Proceeding to Next Month" value={internMonth.proceeding.length} color={C.text} icon={ArrowCircleRightIcon}
                onClick={() => setPersonModal({ title: "Interns Proceeding to the Next Month", subtitle: format(date, "MMMM yyyy"), rows: internMonth.proceeding, kind: "interns" })} />
              <KPICard label="Joining Next Month" value={internMonth.joiningNextMonth.length} subtext={format(new Date(date.getFullYear(), date.getMonth() + 1, 1), "MMMM yyyy")} color={C.teal} icon={PersonAddIcon}
                onClick={() => setPersonModal({ title: "Interns Joining Next Month", subtitle: format(new Date(date.getFullYear(), date.getMonth() + 1, 1), "MMMM yyyy"), rows: internMonth.joiningNextMonth, kind: "interns" })} />
            </Box>
          ) : (
            <Box sx={{ display: "grid", gridTemplateColumns: "repeat(auto-fit, minmax(150px, 1fr))", gap: 1.5 }}>
              <KPICard label="Total Employees" value={cleanEmployees.length} subtext="everyone except interns" color={C.teal} icon={GroupsIcon}
                onClick={() => setPersonModal({ title: "Total Employees", subtitle: "All current employees", rows: cleanEmployees, kind: "employees" })} />
              <KPICard label="Permanent" value={permanentEmp.length} subtext="permanent staff" color={C.teal} icon={HowToRegIcon}
                onClick={() => setPersonModal({ title: "Permanent Employees", subtitle: "Permanent staff", rows: permanentEmp, kind: "employees" })} />
              <KPICard label="On Probation" value={onProbationEmp.length} subtext="still on probation" color={C.orange} icon={AccessTimeIcon}
                onClick={() => setPersonModal({ title: "On Probation", subtitle: "Still on probation", rows: onProbationEmp, kind: "employees" })} />
              <KPICard label="Consultants" value={consultantsEmp.length} subtext="all consultant types" color={C.blue} icon={AccountBalanceIcon}
                onClick={() => setPersonModal({ title: "Consultants", subtitle: "All consultant types", rows: consultantsEmp, kind: "employees" })} />
              <KPICard label={`Left in ${date.getFullYear()}`} value={leftYtdEmp.length} subtext={`last working day between 1 Jan and ${format(date, "d MMM")}`} color={C.red} icon={TimerIcon}
                onClick={() => setPersonModal({ title: `Left in ${date.getFullYear()}`, subtitle: `1 Jan to ${format(date, "d MMM yyyy")}`, rows: leftYtdEmp, kind: "employees" })} />
              <KPICard label="Leaving Soon" value={markedLeaversEmp.length} subtext="resigned but not left yet" color={C.red} icon={ArrowCircleRightIcon}
                onClick={() => setPersonModal({ title: "Leaving Soon", subtitle: "Resigned but not left yet", rows: markedLeaversEmp, kind: "employees" })} />
            </Box>
          )}

          {/* Trend Chart */}
          <Card sx={{ backgroundColor: C.surface, border: `1px solid ${C.border}`, borderRadius: "8px" }}>
            <CardContent sx={{ p: "16px !important" }}>
              <Box sx={{ display: "flex", alignItems: "flex-start", justifyContent: "space-between", mb: 2, flexWrap: "wrap", gap: 1 }}>
                <Box sx={{ display: "flex", alignItems: "center", gap: 1 }}>
                  <TrendingUpIcon sx={{ fontSize: 14, color: C.orange }} />
                  <Box>
                    <Typography sx={{ fontSize: "11px", fontWeight: 700, color: C.text, textTransform: "uppercase", letterSpacing: "0.08em", fontFamily: "monospace" }}>
                      {view === "interns" ? "Interns Over Time" : "Employees Over Time"}
                    </Typography>
                    <Typography sx={{ fontSize: "10px", color: C.muted, fontFamily: "monospace", mt: 0.25 }}>
                      {view === "interns"
                        ? `Highest: ${peakActive} · Joined: ${totalIntake} · Ended: ${totalResign}`
                        : `Highest: ${peakActiveEmp} · Joined: ${totalHiresEmp} · Left: ${totalLeftEmp}`}
                    </Typography>
                  </Box>
                </Box>
                <Stack direction="row" spacing={1} alignItems="center" flexWrap="wrap">
                  <Stack direction="row" spacing={1.5} mr={0.5}>
                    <Box sx={{ display: "flex", alignItems: "center", gap: 0.5 }}>
                      <Box sx={{ width: 6, height: 6, borderRadius: "50%", backgroundColor: C.teal }} />
                      <Typography sx={{ fontSize: "10px", color: C.teal, fontFamily: "monospace" }}>Active</Typography>
                    </Box>
                    <Box sx={{ display: "flex", alignItems: "center", gap: 0.5 }}>
                      <Box sx={{ width: 6, height: 6, borderRadius: "50%", backgroundColor: C.orange }} />
                      <Typography sx={{ fontSize: "10px", color: C.orange, fontFamily: "monospace" }}>Joined</Typography>
                    </Box>
                    <Box sx={{ display: "flex", alignItems: "center", gap: 0.5 }}>
                      <Box sx={{ width: 6, height: 6, borderRadius: "50%", backgroundColor: C.red }} />
                      <Typography sx={{ fontSize: "10px", color: C.red, fontFamily: "monospace" }}>{view === "interns" ? "Ended" : "Left"}</Typography>
                    </Box>
                  </Stack>
                  <ButtonGroup size="small">
                    {["Daily", "Monthly"].map((item) => (
                      <Button key={item} onClick={() => setDetailLevel(item.toLowerCase())} sx={toggleSx(detailLevel === item.toLowerCase())}>{item}</Button>
                    ))}
                  </ButtonGroup>
                  <ButtonGroup size="small">
                    {["3M", "6M", "1Y"].map((item) => (
                      <Button key={item} onClick={() => setTimeRange(item)} sx={toggleSx(timeRange === item)}>{item}</Button>
                    ))}
                  </ButtonGroup>
                  <Button size="small" variant="outlined" startIcon={<DownloadIcon sx={{ fontSize: 12 }} />} onClick={handleExport}
                    sx={{ fontSize: "10px", color: C.orange, borderColor: C.orange, px: 1.5, py: 0.4, "&:hover": { backgroundColor: `${C.orange}11` } }}>
                    Export
                  </Button>
                  <IconButton size="small" onClick={refetch} aria-label="Refresh data" sx={{ color: C.muted, "&:hover": { color: C.text } }}>
                    <RefreshIcon sx={{ fontSize: 15 }} />
                  </IconButton>
                </Stack>
              </Box>

              <Box sx={{ height: { xs: 220, sm: 300 }, border: `1px solid ${C.border}`, borderRadius: "4px", backgroundColor: C.bg, p: 1 }}>
                <ResponsiveContainer width="100%" height="100%">
                  <LineChart data={view === "interns" ? trendData : trendDataEmp} margin={{ top: 4, right: 8, left: 0, bottom: 0 }}>
                    <CartesianGrid stroke={C.border} strokeDasharray="4 4" />
                    <XAxis dataKey="label" stroke={C.border} tick={{ fill: C.muted, fontSize: 9 }} tickLine={false}
                      interval={detailLevel === "daily" ? Math.floor((view === "interns" ? trendData : trendDataEmp).length / 10) : 0} />
                    <YAxis stroke={C.border} tick={{ fill: C.muted, fontSize: 9 }} tickLine={false} axisLine={false} allowDecimals={false} />
                    <RechartsTooltip {...rechartsTooltipProps(C)} />
                    <Line type="monotone" dataKey="active" name="Active" stroke={C.teal} strokeWidth={2} dot={false} activeDot={{ r: 4 }} isAnimationActive={false} />
                    <Line type="monotone" dataKey="intake" name="Joined" stroke={C.orange} strokeWidth={2} dot={false} activeDot={{ r: 4 }} isAnimationActive={false} />
                    <Line type="monotone" dataKey="resignations" name={view === "interns" ? "Ended" : "Left"} stroke={C.red} strokeWidth={2} dot={false} activeDot={{ r: 4 }} isAnimationActive={false} />
                  </LineChart>
                </ResponsiveContainer>
              </Box>
            </CardContent>
          </Card>

          {/* Insight Panels */}
          {view === "interns" && (
            <Grid container spacing={2}>
              <Grid item xs={12} md={4}>
                <SectionCard title="Interns per Mentor" icon={DeviceHubIcon}>
                  <Box sx={{ maxHeight: 400, overflowY: "auto", pr: 0.5 }}>
                    <Stack spacing={1.25}>
                      {mentorData.length ? mentorData.map((item) => (
                        <InsightRow key={item.name} label={item.name} value={item.value} max={mentorData[0]?.value || 1} color={C.blue}
                          onClick={employeesIsLive && item.id ? () => navigate(`/employees/${encodeURIComponent(item.id as string)}`) : undefined} />
                      )) : <EmptyState />}
                    </Stack>
                  </Box>
                </SectionCard>
              </Grid>
              <Grid item xs={12} md={4}>
                <SectionCard title="Interns by Team" icon={GroupsIcon}>
                  <Box sx={{ maxHeight: 400, overflowY: "auto", pr: 0.5 }}>
                    <Stack spacing={1.25}>
                      {teamData.length ? teamData.map((item) => <InsightRow key={item.name} label={item.name} value={item.value} max={teamData[0]?.value || 1} color={C.orange} />) : <EmptyState />}
                    </Stack>
                  </Box>
                </SectionCard>
              </Grid>
              <Grid item xs={12} md={4}>
                <SectionCard title="Interns by University" icon={SchoolIcon}>
                  <Box sx={{ maxHeight: 400, overflowY: "auto", pr: 0.5 }}>
                    <Stack spacing={1.25}>
                      {universityData.length ? universityData.map((item) => <InsightRow key={item.name} label={item.name} value={item.value} max={universityData[0]?.value || 1} color={C.teal} />) : <EmptyState />}
                    </Stack>
                  </Box>
                </SectionCard>
              </Grid>
            </Grid>
          )}

        </>
      )}

      {view === "interns" && subTab === "explore" && (
        <ExplorePanel noun="interns" fields={internFilterFields} options={internFilterOptions}
          filters={internFilters} setFilters={setInternFilters}
          joinedFrom={internJoinedFrom} setJoinedFrom={setInternJoinedFrom} joinedTo={internJoinedTo} setJoinedTo={setInternJoinedTo}
          onClear={clearInternFilters} shown={filteredInterns.length} total={cleanInterns.length}
          onViewList={() => setPersonModal({ title: "Matching Interns", subtitle: `${filteredInterns.length} interns`, rows: filteredInterns, kind: "interns" })}
          stats={exploreInternView.stats} timeline={exploreInternView.timeline} dimensions={exploreInternView.dimensions} />
      )}

      {view === "employees" && subTab === "explore" && (
        <ExplorePanel noun="employees" fields={empFilterFields} options={empFilterOptions}
          filters={empFilters} setFilters={setEmpFilters}
          joinedFrom={empJoinedFrom} setJoinedFrom={setEmpJoinedFrom} joinedTo={empJoinedTo} setJoinedTo={setEmpJoinedTo}
          onClear={clearEmpFilters} shown={filteredEmployees.length} total={cleanEmployees.length}
          onViewList={() => setPersonModal({ title: "Matching Employees", subtitle: `${filteredEmployees.length} employees`, rows: filteredEmployees, kind: "employees" })}
          stats={exploreEmpView.stats} timeline={exploreEmpView.timeline} dimensions={exploreEmpView.dimensions} />
      )}

      {view === "employees" && subTab === "scorecard" && (
        <GroupBreakdown rows={cleanEmployees} kind="employees" />
      )}

      {view === "employees" && subTab === "roles" && (
        <Grid container spacing={2}>
          <Grid item xs={12}>
              <SectionCard title="Job Bands" icon={DeviceHubIcon}
                subtitle={pyramidNoBandCount ? `Number of people in each job band · ${pyramidNoBandCount} people with no job band are not shown` : "Number of people in each job band"}>
                <FormControl size="small" fullWidth sx={{ mb: 2, maxWidth: 360 }}>
                  <Select
                    value={pyramidTeam}
                    onChange={(ev) => setPyramidTeam(ev.target.value)}
                    sx={{
                      backgroundColor: C.bg, color: C.text, fontSize: "13px",
                      "& .MuiOutlinedInput-notchedOutline": { borderColor: C.border },
                      "&:hover .MuiOutlinedInput-notchedOutline": { borderColor: C.orange },
                      "&.Mui-focused .MuiOutlinedInput-notchedOutline": { borderColor: C.orange },
                    }}
                  >
                    <MenuItem value={ALL_TEAMS}>All Teams · {cleanEmployees.length}</MenuItem>
                    {allTeamsEmp.map((t) => (
                      <MenuItem key={t.name} value={t.name}>{t.name} · {t.value}</MenuItem>
                    ))}
                  </Select>
                </FormControl>
                {jobBandPyramidData.some((d) => d.value > 0) ? (
                  <Box sx={{ display: "flex", flexDirection: "column", alignItems: "center", pt: 1, pb: 1, maxWidth: 900, mx: "auto" }}>
                    {/* Pointed apex above the most senior level. */}
                    <Box sx={{
                      width: 0, height: 0, borderLeft: "16px solid transparent", borderRight: "16px solid transparent",
                      borderBottom: `14px solid ${alpha(C.orange, 0.5)}`,
                    }} />
                    {jobBandPyramidData.map((d, i) => {
                      const n = jobBandPyramidData.length;
                      // Fixed step per tier (not proportional to count) so the
                      // shape always reads as a pyramid; real counts are text.
                      const widthPct = 22 + (i / (n - 1)) * 78;
                      return (
                        <Box key={d.name} sx={{
                          width: `${widthPct}%`, minWidth: { xs: 200, sm: 240 }, maxWidth: "100%", boxSizing: "border-box",
                          background: `linear-gradient(180deg, ${alpha(C.orange, 0.22 + i * 0.5 / n)}, ${alpha(C.orange, 0.14 + i * 0.5 / n)})`,
                          borderLeft: `1px solid ${alpha(C.orange, 0.45)}`,
                          borderRight: `1px solid ${alpha(C.orange, 0.45)}`,
                          borderTop: `1px solid ${C.bg}`,
                          borderBottom: i === n - 1 ? `1px solid ${alpha(C.orange, 0.45)}` : "none",
                          borderBottomLeftRadius: i === n - 1 ? "8px" : 0,
                          borderBottomRightRadius: i === n - 1 ? "8px" : 0,
                          boxShadow: `0 2px 4px -2px rgba(0,0,0,0.3)`,
                          py: 1.1, px: 1.5, position: "relative",
                          display: "flex", alignItems: "center", justifyContent: "center", gap: 1.25,
                          opacity: d.value ? 1 : 0.55,
                        }}>
                          <Typography sx={{ fontSize: "11px", fontWeight: 500, color: C.muted, textTransform: "uppercase", letterSpacing: "0.06em", whiteSpace: "nowrap" }}>{d.name}</Typography>
                          <Box sx={{
                            minWidth: 34, px: 1, py: 0.15, borderRadius: "999px", textAlign: "center",
                            backgroundColor: C.bg, border: `1px solid ${alpha(C.orange, 0.6)}`,
                            fontSize: "13px", fontWeight: 800, color: C.orange, fontFamily: "monospace", whiteSpace: "nowrap",
                          }}>{d.value}</Box>
                        </Box>
                      );
                    })}
                  </Box>
                ) : <EmptyState />}
              </SectionCard>
          </Grid>
          <Grid item xs={12}>
              <SectionCard title="Job Bands by Team" icon={GroupsIcon} subtitle="Darker boxes mean more people · click a team to see it above">
                {jobBandByTeamEmp.length ? (
                  <Box sx={{ overflowX: "auto" }}>
                    <Box component="table" sx={{ width: "100%", borderCollapse: "separate", borderSpacing: "3px 2px", fontSize: "12px" }}>
                      <Box component="thead">
                        <Box component="tr">
                          <Box component="th" sx={{ textAlign: "left", color: C.muted, fontWeight: 600, fontSize: "10.5px", pb: 0.75 }}>Team</Box>
                          {jobBandColumns.map((col) => (
                            <Box component="th" key={col} sx={{ color: C.muted, fontWeight: 600, fontSize: "10.5px", pb: 0.75, textAlign: "center", whiteSpace: "nowrap" }}>
                              {col.replace("Band ", "")}
                            </Box>
                          ))}
                          <Box component="th" sx={{ color: C.text, fontWeight: 700, fontSize: "10.5px", pb: 0.75, textAlign: "right" }}>Total</Box>
                        </Box>
                      </Box>
                      <Box component="tbody">
                        <Box component="tr" onClick={() => setPyramidTeam(ALL_TEAMS)}
                          sx={{ cursor: "pointer", "&:hover td:first-of-type": { color: C.orange } }}>
                          <Box component="td" sx={{ color: pyramidTeam === ALL_TEAMS ? C.orange : C.text, fontWeight: 800, pr: 1, pb: 0.75, whiteSpace: "nowrap", borderBottom: `2px solid ${C.border}` }}>
                            All Employees
                          </Box>
                          {jobBandColumns.map((col) => {
                            const n = jobBandAllRow.counts[col] || 0;
                            // Scaled against the company-wide row itself, not the per-team max.
                            const intensity = n ? 0.12 + 0.78 * (n / jobBandAllRow.max) : 0;
                            return (
                              <Box component="td" key={col} title={`All employees · ${col}: ${n}`} sx={{
                                textAlign: "center", fontFamily: "monospace", py: 0.65, minWidth: 38, borderRadius: "4px",
                                backgroundColor: n ? alpha(C.orange, intensity) : C.hover,
                                color: n ? (intensity > 0.55 ? "#FFFFFF" : C.text) : C.dim,
                                fontWeight: 800, borderBottom: `2px solid ${C.border}`,
                                outline: pyramidTeam === ALL_TEAMS ? `1px solid ${alpha(C.orange, 0.6)}` : "none",
                              }}>{n || "·"}</Box>
                            );
                          })}
                          <Box component="td" sx={{ textAlign: "right", fontFamily: "monospace", fontWeight: 800, color: C.text, pl: 1, borderBottom: `2px solid ${C.border}` }}>{jobBandAllRow.total}</Box>
                        </Box>
                        {jobBandByTeamEmp.map((row) => {
                          const selected = pyramidTeam === row.name;
                          return (
                            <Box component="tr" key={row.name} onClick={() => setPyramidTeam(selected ? ALL_TEAMS : row.name)}
                              sx={{ cursor: "pointer", "&:hover td:first-of-type": { color: C.orange } }}>
                              <Box component="td" sx={{
                                color: selected ? C.orange : C.text, fontWeight: selected ? 700 : 500, pr: 1, whiteSpace: "nowrap",
                                maxWidth: 170, overflow: "hidden", textOverflow: "ellipsis",
                              }}>{row.name}</Box>
                              {jobBandColumns.map((col) => {
                                const n = (row as any)[col] || 0;
                                const intensity = n ? 0.12 + 0.78 * (n / jobBandCellMax) : 0;
                                return (
                                  <Box component="td" key={col} title={`${row.name} · ${col}: ${n}`} sx={{
                                    textAlign: "center", fontFamily: "monospace", py: 0.55, minWidth: 38, borderRadius: "4px",
                                    backgroundColor: n ? alpha(C.orange, intensity) : C.hover,
                                    color: n ? (intensity > 0.55 ? "#FFFFFF" : C.text) : C.dim,
                                    fontWeight: n ? 600 : 400,
                                    outline: selected ? `1px solid ${alpha(C.orange, 0.6)}` : "none",
                                  }}>{n || "·"}</Box>
                                );
                              })}
                              <Box component="td" sx={{ textAlign: "right", fontFamily: "monospace", fontWeight: 700, color: C.text, pl: 1 }}>{row.total}</Box>
                            </Box>
                          );
                        })}
                      </Box>
                    </Box>
                  </Box>
                ) : <EmptyState />}
              </SectionCard>
          </Grid>
        </Grid>
      )}

      {view === "employees" && subTab === "demographics" && (
        <Flow>
          <FlowItem basis={480}>
            <StackedBarCard title="Gender in Each Business Unit" icon={AccountBalanceIcon} subtitle="10 largest business units"
              rows={peopleEmp.genderByBu} keys={["Male", "Female"]} colors={{ Male: C.blue, Female: C.purple }} />
          </FlowItem>
          <FlowItem basis={480}>
            <StackedBarCard title="Years at the Company by Gender" icon={TimerIcon} subtitle="Men and women in each group"
              rows={peopleEmp.tenureByGender} keys={["Male", "Female"]} colors={{ Male: C.blue, Female: C.purple }} />
          </FlowItem>
          <FlowItem basis={480}>
            <SectionCard title="Gender by Team" icon={DeviceHubIcon}>
              <GenderBreakdownTable data={genderByTeamEmp} />
            </SectionCard>
          </FlowItem>
          <FlowItem basis={480}>
            <SectionCard title="Gender by Location" icon={AccountBalanceIcon}>
              <GenderBreakdownTable data={genderByLocationEmp} />
            </SectionCard>
          </FlowItem>
        </Flow>
      )}

      {view === "employees" && subTab === "trends" && (
        <Flow>
              <FlowItem basis={440}>
                <SectionCard title="People Who Left, by Team" icon={GroupsIcon} subtitle="In the selected time range">
                  {leaversByTeamEmp.length ? (
                    <Box sx={{ height: 260 }}>
                      <ResponsiveContainer width="100%" height="100%">
                        <BarChart data={leaversByTeamEmp} layout="vertical" margin={{ left: 8, right: 16 }}>
                          <CartesianGrid stroke={C.border} strokeDasharray="4 4" horizontal={false} />
                          <XAxis type="number" stroke={C.border} tick={{ fill: C.muted, fontSize: 9, fontFamily: "monospace" }} tickLine={false} axisLine={false} allowDecimals={false} />
                          <YAxis type="category" dataKey="name" stroke={C.border} tick={{ fill: C.text, fontSize: 10.5 }} tickLine={false} axisLine={false} width={isPhone ? 90 : 150} />
                          <RechartsTooltip {...rechartsTooltipProps(C)} />
                          <Bar dataKey="value" name="Left" fill={C.red} radius={[0, 3, 3, 0]} />
                        </BarChart>
                      </ResponsiveContainer>
                    </Box>
                  ) : <EmptyState label="No one left in this time range" />}
                </SectionCard>
              </FlowItem>
              <FlowItem basis={440}>
                <SectionCard title="People Who Joined, by Team" icon={PersonAddIcon} subtitle="In the selected time range">
                  {hiresByTeamEmp.length ? (
                    <Box sx={{ height: 260 }}>
                      <ResponsiveContainer width="100%" height="100%">
                        <BarChart data={hiresByTeamEmp} layout="vertical" margin={{ left: 8, right: 16 }}>
                          <CartesianGrid stroke={C.border} strokeDasharray="4 4" horizontal={false} />
                          <XAxis type="number" stroke={C.border} tick={{ fill: C.muted, fontSize: 9, fontFamily: "monospace" }} tickLine={false} axisLine={false} allowDecimals={false} />
                          <YAxis type="category" dataKey="name" stroke={C.border} tick={{ fill: C.text, fontSize: 10.5 }} tickLine={false} axisLine={false} width={isPhone ? 90 : 150} />
                          <RechartsTooltip {...rechartsTooltipProps(C)} />
                          <Bar dataKey="value" name="Hired" fill={C.teal} radius={[0, 3, 3, 0]} />
                        </BarChart>
                      </ResponsiveContainer>
                    </Box>
                  ) : <EmptyState label="No one joined in this time range" />}
                </SectionCard>
              </FlowItem>
              <FlowItem basis={440}>
                <SectionCard title="How Long Leavers Stayed" icon={TimerIcon} subtitle="For people who left in the selected time range">
                  {exitTenureEmp.some((d) => d.value) ? (
                    <Box sx={{ height: 260 }}>
                      <ResponsiveContainer width="100%" height="100%">
                        <BarChart data={exitTenureEmp} barCategoryGap="30%">
                          <CartesianGrid stroke={C.border} strokeDasharray="4 4" vertical={false} />
                          <XAxis dataKey="name" stroke={C.border} tick={{ fill: C.muted, fontSize: 9 }} tickLine={false} axisLine={false} interval={0} />
                          <YAxis stroke={C.border} tick={{ fill: C.muted, fontSize: 9 }} tickLine={false} axisLine={false} allowDecimals={false} width={32} />
                          <RechartsTooltip {...rechartsTooltipProps(C)} />
                          <Bar dataKey="value" name="Left" fill={C.red} radius={[3, 3, 0, 0]} />
                        </BarChart>
                      </ResponsiveContainer>
                    </Box>
                  ) : <EmptyState label="No one left in this time range" />}
                </SectionCard>
              </FlowItem>
              <FlowItem full>
                <SectionCard title="Employees Each Year" icon={TrendingUpIcon} subtitle="Number of employees at the end of each year, and today">
                  <Box sx={{ height: 240 }}>
                    <ResponsiveContainer width="100%" height="100%">
                      <BarChart data={yearlyHeadcountEmp} barCategoryGap="35%">
                        <CartesianGrid stroke={C.border} strokeDasharray="4 4" vertical={false} />
                        <XAxis dataKey="label" stroke={C.border} tick={{ fill: C.muted, fontSize: 10 }} tickLine={false} axisLine={false} />
                        <YAxis stroke={C.border} tick={{ fill: C.muted, fontSize: 9 }} tickLine={false} axisLine={false} allowDecimals={false} width={36} />
                        <RechartsTooltip {...rechartsTooltipProps(C)} />
                        <Bar dataKey="value" name="Employees" fill={C.orange} radius={[3, 3, 0, 0]} label={{ position: "top", fill: C.text, fontSize: 11 }} />
                      </BarChart>
                    </ResponsiveContainer>
                  </Box>
                </SectionCard>
              </FlowItem>
        </Flow>
      )}

      <PersonListModal modal={personModal} search={modalSearch} onSearchChange={setModalSearch}
        employeesIsLive={employeesIsLive}
        onClose={() => setPersonModal(null)}
        onOpenPerson={(path) => { setPersonModal(null); navigate(path); }} />

    </Box>
  );
}

function PersonListModal({ modal, search, onSearchChange, employeesIsLive, onClose, onOpenPerson }: {
  modal: PersonModal | null;
  search: string;
  onSearchChange: (v: string) => void;
  employeesIsLive: boolean;
  onClose: () => void;
  onOpenPerson: (path: string) => void;
}) {
  // Uses the Dashboard's own color tokens (not plain MUI theme palette) so
  // this modal reads as part of the same screen it's opened from - same
  // surface/border/orange-accent language as the KPI tiles and tabs behind
  // it, instead of a generic default-MUI dialog dropped on top.
  const C = useEmployeeHubColors();
  const theme = useTheme();
  const isPhone = useMediaQuery(theme.breakpoints.down("sm"));
  const isIntern = modal?.kind === "interns";

  const mapped = useMemo(() => {
    if (!modal) return [];
    const people = modal.kind === "interns"
      ? modal.rows.map((i) => ({ id: i.employeeId || i.id, name: i.name, group: i.bu, role: i.team || "—", joined: i.joinedDate || "" }))
      : modal.rows.map((e) => ({ id: e.employeeId, name: e.name, group: e.team || e.bu, role: e.designation || "—", joined: e.joinDate || "" }));
    return people.map((p, i) => ({
      ...p,
      key: `${p.id}-${i}`,
      name: p.name || "Unnamed",
      group: canonicalGroupKey(p.group) || "Unspecified",
      // Links to the person's people-app profile (/employees/:id), once the
      // employee fetch has succeeded; until then rows stay unclickable.
      path: employeesIsLive && p.id ? `/employees/${encodeURIComponent(p.id)}` : null,
    }));
  }, [modal, employeesIsLive]);

  const filtered = useMemo(() => {
    if (!search) return mapped;
    const q = search.toLowerCase();
    return mapped.filter((p) => `${p.name} ${p.group} ${p.role}`.toLowerCase().includes(q));
  }, [mapped, search]);

  // Grouped by team, largest first, so index 0 - the biggest, most-scrolled
  // section - always lands on brand orange rather than an arbitrary hue.
  const grouped = useMemo(() => {
    const map: Record<string, typeof filtered> = {};
    filtered.forEach((p) => { (map[p.group] ||= []).push(p); });
    return Object.entries(map).sort((a, b) => b[1].length - a[1].length);
  }, [filtered]);
  const GROUP_COLORS = [C.orange, C.teal, C.blue, C.red, C.yellow, C.purple];

  // Same column layout used by the avatar/name column, shared between the
  // header row and every body row so they stay pixel-aligned.
  // Phones only get avatar, name and group - the rest doesn't fit.
  const COLUMNS = isPhone
    ? "32px minmax(0, 1.4fr) minmax(0, 1fr)"
    : "40px minmax(140px, 1.5fr) minmax(90px, 0.8fr) minmax(120px, 1fr) 90px";
  return (
    <Dialog open={!!modal} onClose={onClose} maxWidth="md" fullWidth fullScreen={isPhone}
      PaperProps={{
        elevation: 0,
        sx: {
          backgroundColor: C.surface, backgroundImage: "none", border: `1px solid ${C.border}`,
          borderRadius: isPhone ? 0 : "10px", maxHeight: isPhone ? "100%" : "82vh", position: "relative", overflow: "hidden",
          "&::before": { content: '""', position: "absolute", top: 0, left: 0, right: 0, height: "3px", backgroundColor: C.orange },
        },
      }}>
      <DialogTitle sx={{ pb: 1.5, pt: 2.5 }}>
        <Box sx={{ display: "flex", alignItems: "flex-start", justifyContent: "space-between" }}>
          <Box>
            <Typography sx={{ fontWeight: 700, fontSize: "1.05rem", lineHeight: 1.3, color: C.text }}>{modal?.title}</Typography>
            <Typography sx={{ fontSize: "11px", fontFamily: "monospace", letterSpacing: "0.03em", color: C.muted, mt: 0.5 }}>
              {modal?.subtitle} · {filtered.length}{filtered.length !== mapped.length ? ` of ${mapped.length}` : ""} PEOPLE
            </Typography>
          </Box>
          <IconButton size="small" onClick={onClose} aria-label="Close dialog" sx={{ color: C.muted, "&:hover": { color: C.text, backgroundColor: C.hover } }}>
            <CloseIcon fontSize="small" />
          </IconButton>
        </Box>
      </DialogTitle>
      <DialogContent sx={{ pt: 0 }}>
        {mapped.length > 6 && (
          <TextField
            size="small" fullWidth value={search} onChange={(e) => onSearchChange(e.target.value)}
            placeholder="Filter this list..."
            InputProps={{ startAdornment: <InputAdornment position="start"><SearchIcon fontSize="small" sx={{ color: C.muted }} /></InputAdornment> }}
            sx={{
              mb: 2.5,
              "& .MuiOutlinedInput-root": {
                backgroundColor: C.bg,
                "& fieldset": { borderColor: C.border },
                "&:hover fieldset": { borderColor: C.orange },
                "&.Mui-focused fieldset": { borderColor: C.orange },
              },
              input: { color: C.text },
            }}
          />
        )}
        {modal && filtered.length === 0 && (
          <Box sx={{ py: 4, textAlign: "center" }}>
            <Typography variant="body2" sx={{ color: C.muted }}>
              {search ? "No matches for this search" : "No one in this list for the selected period"}
            </Typography>
          </Box>
        )}
        {filtered.length > 0 && (
          <Box sx={{ border: `1px solid ${C.border}`, borderRadius: "6px", overflow: "hidden" }}>
            <Box sx={{
              display: "grid", gridTemplateColumns: COLUMNS, alignItems: "center", gap: 1.5, px: 1.5, py: 1,
              backgroundColor: theme.palette.mode === "dark" ? theme.palette.grey[800] : theme.palette.grey[100],
              fontSize: "0.7rem", fontWeight: 700, textTransform: "uppercase", letterSpacing: "0.05em", color: C.muted,
            }}>
              <Box />
              <Box>Name</Box>
              <Box>{isIntern ? "Business Unit" : "Team"}</Box>
              {!isPhone && <Box>{isIntern ? "Team" : "Designation"}</Box>}
              {!isPhone && <Box>Joined</Box>}
            </Box>
            {grouped.map(([group, people], groupIndex) => {
              const gc = GROUP_COLORS[groupIndex % GROUP_COLORS.length];
              return (
                <Box key={group}>
                  <Box sx={{
                    display: "flex", alignItems: "center", gap: 1, px: 1.5, py: 0.75, borderTop: `1px solid ${C.border}`,
                    backgroundColor: alpha(gc, theme.palette.mode === "dark" ? 0.12 : 0.06),
                  }}>
                    <Box sx={{ width: 6, height: 6, borderRadius: "50%", backgroundColor: gc, flexShrink: 0 }} />
                    <Typography sx={{ fontWeight: 700, fontSize: "11px", fontFamily: "monospace", textTransform: "uppercase", letterSpacing: "0.06em", color: C.text }}>
                      {group}
                    </Typography>
                    <Typography sx={{ fontSize: "11px", fontFamily: "monospace", color: C.muted }}>
                      {people.length}
                    </Typography>
                  </Box>
                  {people.map((p) => (
                    <Box
                      key={p.key}
                      onClick={() => { if (p.path) onOpenPerson(p.path); }}
                      sx={{
                        display: "grid", gridTemplateColumns: COLUMNS, alignItems: "center", gap: 1.5, px: 1.5, py: 1, minWidth: 0,
                        borderTop: `1px solid ${C.border}`,
                        cursor: p.path ? "pointer" : "default",
                        transition: "background-color 0.15s",
                        "&:hover": p.path ? { backgroundColor: C.hover } : {},
                      }}
                    >
                      <Avatar sx={{
                        width: 28, height: 28, fontSize: "0.75rem", fontWeight: 700, color: gc,
                        bgcolor: alpha(gc, theme.palette.mode === "dark" ? 0.28 : 0.14),
                      }}>
                        {p.name[0]?.toUpperCase() || "?"}
                      </Avatar>
                      <Typography variant="body2" sx={{ fontWeight: 600, color: C.text, overflow: "hidden", textOverflow: "ellipsis", whiteSpace: "nowrap" }}>
                        {p.name}
                      </Typography>
                      <Typography variant="body2" sx={{ color: C.muted, overflow: "hidden", textOverflow: "ellipsis", whiteSpace: "nowrap" }}>
                        {p.group}
                      </Typography>
                      {!isPhone && <Typography variant="body2" sx={{ color: C.muted, overflow: "hidden", textOverflow: "ellipsis", whiteSpace: "nowrap" }}>
                        {p.role}
                      </Typography>}
                      {!isPhone && <Typography variant="body2" sx={{ color: C.muted, whiteSpace: "nowrap" }}>
                        {p.joined ? formatReadableDate(p.joined) : "—"}
                      </Typography>}
                    </Box>
                  ))}
                </Box>
              );
            })}
          </Box>
        )}
      </DialogContent>
    </Dialog>
  );
}
