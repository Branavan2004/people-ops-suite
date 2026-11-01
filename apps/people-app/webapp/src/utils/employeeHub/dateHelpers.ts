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

import dayjs from "dayjs";

/**
 * Resilient to the mixed date formats found in the source data (YYYY-MM-DD,
 * DD-MMM-YYYY, MMM YYYY, DD/MM/YYYY, DD-MM-YYYY).
 */
export const parseDate = (dateStr: unknown): Date | null => {
  if (!dateStr) return null;
  if (dateStr instanceof Date) return dateStr;

  const str = String(dateStr).trim();

  // new Date("YYYY-MM-DD") is UTC midnight, which lands on the previous day
  // or at a non-midnight hour in most timezones; dayjs reads it as local
  // midnight, matching every other Date this dashboard compares against.
  if (/^\d{4}-\d{2}-\d{2}$/.test(str)) {
    const d = dayjs(str);
    return d.isValid() ? d.toDate() : null;
  }

  if (/^\d{1,2}-[A-Za-z]{3}-\d{4}$/.test(str)) {
    const parts = str.split("-");
    const day = parseInt(parts[0], 10);
    const monthStr = parts[1];
    const year = parseInt(parts[2], 10);
    const month = new Date(`${monthStr} 1, ${year}`).getMonth();
    if (!isNaN(day) && !isNaN(month) && !isNaN(year)) {
      const d = new Date(year, month, day);
      return isNaN(d.getTime()) ? null : d;
    }
  }

  if (/^[A-Za-z]{3,9}\s+\d{4}$/.test(str)) {
    const parts = str.split(" ");
    const month = new Date(`${parts[0]} 1, ${parts[1]}`).getMonth();
    const year = parseInt(parts[1], 10);
    if (!isNaN(month) && !isNaN(year)) {
      const d = new Date(year, month, 1);
      return isNaN(d.getTime()) ? null : d;
    }
  }

  const slashParts = str.split("/");
  if (slashParts.length === 3) {
    const day = parseInt(slashParts[0], 10);
    const month = parseInt(slashParts[1], 10) - 1;
    const year = parseInt(slashParts[2], 10);
    if (!isNaN(day) && !isNaN(month) && !isNaN(year)) {
      const d = new Date(year, month, day);
      return isNaN(d.getTime()) ? null : d;
    }
  }

  const dashParts = str.split("-");
  if (dashParts.length === 3 && dashParts[0].length <= 2) {
    const day = parseInt(dashParts[0], 10);
    const month = parseInt(dashParts[1], 10) - 1;
    const year = parseInt(dashParts[2], 10);
    if (!isNaN(day) && !isNaN(month) && !isNaN(year)) {
      const d = new Date(year, month, day);
      return isNaN(d.getTime()) ? null : d;
    }
  }

  const fallback = new Date(str);
  return isNaN(fallback.getTime()) ? null : fallback;
};

const MONTH_ABBR = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"];
const MONTH_FULL = ["January", "February", "March", "April", "May", "June", "July", "August", "September", "October", "November", "December"];

// Tiny stand-in for a date `format()`, covering only the handful of tokens
// this dashboard uses (yyyy, yy, MMMM, MMM, MM, dd, d).
export const formatDateToken = (date: Date, pattern: string): string => {
  const yyyy = String(date.getFullYear());
  const yy = yyyy.slice(-2);
  const MMMM = MONTH_FULL[date.getMonth()];
  const MMM = MONTH_ABBR[date.getMonth()];
  const MM = String(date.getMonth() + 1).padStart(2, "0");
  const dd = String(date.getDate()).padStart(2, "0");
  const d = String(date.getDate());
  const tokens: Record<string, string> = { yyyy, yy, MMMM, MMM, MM, dd, d };
  return pattern.replace(/yyyy|yy|MMMM|MMM|MM|dd|d/g, (match) => tokens[match]);
};

// Midnight at the start of the given day, for comparing against the
// date-only values parseDate returns.
export const startOfDay = (date: Date): Date => new Date(date.getFullYear(), date.getMonth(), date.getDate());

export const isDateToday = (date: Date): boolean => {
  const today = new Date();
  return date.getFullYear() === today.getFullYear() && date.getMonth() === today.getMonth() && date.getDate() === today.getDate();
};

export const formatReadableDate = (date: unknown): string => {
  const parsed = parseDate(date);
  if (!parsed) return "N/A";
  return parsed.toLocaleDateString("en-US", {
    year: "numeric",
    month: "short",
    day: "numeric",
  });
};

export const isSameMonthAndYear = (date: unknown, targetDate: unknown): boolean => {
  const d1 = parseDate(date);
  const d2 = parseDate(targetDate);
  if (!d1 || !d2) return false;
  return d1.getMonth() === d2.getMonth() && d1.getFullYear() === d2.getFullYear();
};

export const isPreviousMonthAndYear = (date: unknown, targetDate: unknown): boolean => {
  const d1 = parseDate(date);
  const d2 = parseDate(targetDate);
  if (!d1 || !d2) return false;

  let targetMonth = d2.getMonth() - 1;
  let targetYear = d2.getFullYear();
  if (targetMonth < 0) {
    targetMonth = 11;
    targetYear -= 1;
  }

  return d1.getMonth() === targetMonth && d1.getFullYear() === targetYear;
};

export const getLastDayOfMonth = (targetDate: unknown): Date | null => {
  const d = parseDate(targetDate);
  if (!d) return null;
  return new Date(d.getFullYear(), d.getMonth() + 1, 0);
};
