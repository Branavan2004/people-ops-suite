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

import { Box, ClickAwayListener, Fade, Paper, Popper, Stack, Typography } from "@mui/material";
import { Check, ChevronDown, X } from "lucide-react";
import { useMemo, useRef, useState } from "react";

import { Job } from "@/types/types";
import { RootState, useAppSelector } from "@slices/store";
import { matchesLocation, matchesTeam } from "@utils/jobFilterUtils";

export interface JobFilterValues {
  team: string[];
  location: string[];
}

interface JobFiltersProps {
  // Jobs already narrowed by search, tab and job type, but not by these dropdowns.
  jobs: Job[];
  filters: JobFilterValues;
  onChange: (filters: JobFilterValues) => void;
  // Whether the page's search box has text, so "Clear all" also shows for a search with no filters chosen.
  searchActive: boolean;
  // Resets the dropdown selections and the page's search text together.
  onClearAll: () => void;
}

type DropdownKey = "team" | "location";

const KEY_LABELS: Record<DropdownKey, string> = { team: "Team", location: "Location" };

const JobFilters = ({ jobs, filters, onChange, searchActive, onClearAll }: JobFiltersProps) => {
  const { locations, teams } = useAppSelector((state: RootState) => state.careers.orgStructure);
  const [openDropdown, setOpenDropdown] = useState<DropdownKey | null>(null);
  const teamAnchor = useRef<HTMLButtonElement>(null);
  const locationAnchor = useRef<HTMLButtonElement>(null);

  // How many open positions each option would match given the other dropdown's selection; a dropdown's counts ignore
  // its own selection.
  const teamCounts = useMemo(() => {
    const scoped = jobs.filter((job) => matchesLocation(job, filters.location));
    const counts: Record<string, number> = {};
    teams.forEach((team) => {
      counts[team] = scoped.filter((job) => job.team === team).length;
    });
    return counts;
  }, [jobs, teams, filters.location]);

  const locationCounts = useMemo(() => {
    const scoped = jobs.filter((job) => matchesTeam(job, filters.team));
    const counts: Record<string, number> = {};
    locations.forEach((loc) => {
      counts[loc] = scoped.filter((job) => matchesLocation(job, [loc])).length;
    });
    return counts;
  }, [jobs, locations, filters.team]);

  const counts: Record<DropdownKey, Record<string, number>> = { team: teamCounts, location: locationCounts };

  const anchors: Record<DropdownKey, React.RefObject<HTMLButtonElement | null>> = {
    team: teamAnchor,
    location: locationAnchor,
  };

  const toggleValue = (key: DropdownKey, value: string) => {
    const current = filters[key];
    const next = current.includes(value) ? current.filter((v) => v !== value) : [...current, value];
    onChange({ ...filters, [key]: next });
  };

  const removeChip = (key: DropdownKey, value: string) => {
    onChange({ ...filters, [key]: filters[key].filter((v) => v !== value) });
  };

  const clearAll = onClearAll;

  const activeChips: { key: DropdownKey; value: string }[] = [
    ...filters.team.map((value) => ({ key: "team" as const, value })),
    ...filters.location.map((value) => ({ key: "location" as const, value })),
  ];
  const hasActive = activeChips.length > 0 || searchActive;

  const renderDropdown = (key: DropdownKey, label: string, options: string[], columns: number) => {
    const selected = filters[key];
    const isOpen = openDropdown === key;

    return (
      <Box sx={{ position: "relative", height: "40px" }}>
        <Box
          component="div"
          role="button"
          tabIndex={0}
          aria-haspopup="true"
          aria-expanded={isOpen}
          ref={anchors[key]}
          onClick={() => setOpenDropdown(isOpen ? null : key)}
          onKeyDown={(e) => {
            if (e.key === "Enter" || e.key === " ") {
              e.preventDefault();
              setOpenDropdown(isOpen ? null : key);
            } else if (e.key === "Escape") {
              setOpenDropdown(null);
            }
          }}
          sx={{
            display: "flex",
            alignItems: "center",
            justifyContent: "space-between",
            gap: 1,
            width: "100%",
            height: "100%",
            minWidth: 0,
            padding: "0 12px",
            backgroundColor: "background.glass",
            border: "1px solid",
            borderColor: (theme) =>
              isOpen ? theme.palette.primary.main : theme.palette.mode === "dark" ? theme.palette.divider : "rgba(0,0,0,0.15)",
            outline: "none",
            borderRadius: "40px",
            textAlign: "left",
            cursor: "pointer",
            transition: "border-color 0.15s",
            "&:hover, &:focus-visible": { borderColor: "primary.main" },
          }}
        >
          <Typography
            component="span"
            noWrap
            sx={{
              fontSize: "1rem",
              fontWeight: 400,
              color: selected.length > 0 ? "text.primary" : "text.secondary",
            }}
          >
            {/* The placeholder when nothing is chosen; otherwise the first choice, with "+N" for the others. */}
            {selected.length === 0 ? label : `${selected[0]}${selected.length > 1 ? ` +${selected.length - 1}` : ""}`}
          </Typography>
          <Stack direction="row" alignItems="center" gap={0.5} sx={{ flexShrink: 0 }}>
            {selected.length > 0 && (
              <Box
                component="button"
                type="button"
                aria-label={`Clear ${label} filter`}
                // Clears just this dropdown's selection without opening or closing its list.
                onClick={(e) => {
                  e.stopPropagation();
                  onChange({ ...filters, [key]: [] });
                }}
                onKeyDown={(e) => e.stopPropagation()}
                sx={{
                  display: "flex",
                  border: "none",
                  background: "none",
                  cursor: "pointer",
                  p: 0.5,
                  borderRadius: "50%",
                  color: "text.secondary",
                  "&:hover": { backgroundColor: "action.hover", color: "primary.main" },
                }}
              >
                <X size={14} />
              </Box>
            )}
            <ChevronDown
              size={16}
              color="#6b7591"
              style={{
                flexShrink: 0,
                transition: "transform 0.2s",
                transform: isOpen ? "rotate(180deg)" : "none",
              }}
            />
          </Stack>
        </Box>

        <Popper
          open={isOpen}
          anchorEl={anchors[key].current}
          placement="bottom-start"
          transition
          disablePortal
          sx={{ zIndex: 60 }}
        >
          {({ TransitionProps }) => (
            <Fade {...TransitionProps} timeout={150}>
              <Paper
                onKeyDown={(e) => {
                  if (e.key === "Escape") {
                    setOpenDropdown(null);
                    anchors[key].current?.focus();
                  }
                }}
                sx={{
                  mt: "6px",
                  minWidth: 240,
                  maxWidth: 440,
                  maxHeight: 320,
                  overflowY: "auto",
                  border: "1px solid",
                  borderColor: "divider",
                  borderRadius: "12px",
                  boxShadow: "0 20px 50px -12px rgb(7 20 46 / 20%), 0 4px 8px rgb(7 20 46 / 4%)",
                  padding: "8px",
                  columnCount: { xs: 1, sm: columns },
                  columnGap: 0,
                }}
              >
                {options.map((opt) => {
                  const checked = selected.includes(opt);
                  const count = counts[key][opt] ?? 0;
                  // A selected option stays clickable at zero so it can always be deselected.
                  const disabled = count === 0 && !checked;
                  return (
                    <Box
                      key={opt}
                      component="button"
                      disabled={disabled}
                      onClick={() => toggleValue(key, opt)}
                      sx={{
                        opacity: disabled ? 0.45 : 1,
                        display: "flex",
                        alignItems: "center",
                        gap: "10px",
                        width: "100%",
                        padding: "9px 10px",
                        border: "none",
                        background: "none",
                        borderRadius: "6px",
                        fontSize: "14px",
                        color: "text.primary",
                        textAlign: "left",
                        cursor: disabled ? "not-allowed" : "pointer",
                        breakInside: "avoid",
                        "&:hover": { backgroundColor: disabled ? "transparent" : "action.hover" },
                      }}
                    >
                      <Box
                        sx={{
                          display: "flex",
                          alignItems: "center",
                          justifyContent: "center",
                          width: 16,
                          height: 16,
                          flexShrink: 0,
                          backgroundColor: checked ? "#ff6700" : "background.glass",
                          border: "1.5px solid",
                          borderColor: checked ? "#ff6700" : "text.secondary",
                          borderRadius: "4px",
                        }}
                      >
                        {checked && <Check size={11} color="#fff" strokeWidth={3} />}
                      </Box>
                      <Box component="span" sx={{ flex: 1, overflow: "hidden", textOverflow: "ellipsis" }}>
                        {opt}
                      </Box>
                      <Box
                        component="span"
                        sx={{
                          flexShrink: 0,
                          minWidth: 20,
                          height: 20,
                          px: "6px",
                          borderRadius: "999px",
                          background: disabled ? "#9ca3af" : "#ff6700",
                          color: "#fff",
                          fontSize: "11px",
                          fontWeight: 700,
                          display: "flex",
                          alignItems: "center",
                          justifyContent: "center",
                        }}
                      >
                        {count}
                      </Box>
                    </Box>
                  );
                })}
              </Paper>
            </Fade>
          )}
        </Popper>
      </Box>
    );
  };

  return (
    <ClickAwayListener onClickAway={() => setOpenDropdown(null)}>
      <Box>
        <Box
          sx={{
            display: "grid",
            gridTemplateColumns: { xs: "1fr", sm: "repeat(2, minmax(0, 1fr))" },
            gap: 2,
            alignItems: "center",
          }}
        >
          {renderDropdown("team", "Team", teams, 2)}
          {renderDropdown("location", "Location", locations, 3)}
        </Box>

        {hasActive && (
          <Stack direction="row" flexWrap="wrap" alignItems="center" gap={1} sx={{ mt: 2 }}>
            {activeChips.map(({ key, value }) => (
              <Stack
                key={`${key}-${value}`}
                direction="row"
                alignItems="center"
                gap={0.75}
                sx={{
                  padding: "6px 10px 6px 14px",
                  backgroundColor: "background.glass",
                  border: "1px solid",
                  borderColor: "divider",
                  borderRadius: "999px",
                  fontSize: "13px",
                  color: "text.primary",
                }}
              >
                <span>
                  {KEY_LABELS[key]}: <strong>{value}</strong>
                </span>
                <Box
                  component="button"
                  aria-label={`Remove ${KEY_LABELS[key]} ${value}`}
                  onClick={() => removeChip(key, value)}
                  sx={{ display: "flex", border: "none", background: "none", cursor: "pointer", p: 0, color: "primary.main" }}
                >
                  <X size={13} />
                </Box>
              </Stack>
            ))}
            <Box
              component="button"
              onClick={clearAll}
              sx={{
                background: "none",
                border: "none",
                padding: "6px 8px",
                fontSize: "13px",
                fontWeight: 600,
                color: "primary.main",
                cursor: "pointer",
              }}
            >
              Clear all
            </Box>
          </Stack>
        )}
      </Box>
    </ClickAwayListener>
  );
};

export default JobFilters;
