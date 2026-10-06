#!/system/bin/sh
#
# Conservative RTC fallback for recovery.
#
# The stock kernel normally initializes CLOCK_REALTIME from the PMIC RTC.
# If that did not happen and recovery starts with an epoch-like year, copy the
# readable rtc0 value into CLOCK_REALTIME. Never write back to the hardware RTC.
#

LOG=/tmp/recovery-time.log
RTC=/sys/class/rtc/rtc0

system_before="$(date -u '+%Y-%m-%d %H:%M:%S UTC' 2>/dev/null)"
echo "system_before=${system_before}" > "${LOG}"

if [ ! -r "${RTC}/date" ] || [ ! -r "${RTC}/time" ]; then
    echo "rtc0=unavailable" >> "${LOG}"
    exit 0
fi

rtc_date="$(cat "${RTC}/date" 2>/dev/null)"
rtc_time="$(cat "${RTC}/time" 2>/dev/null)"
sys_year="$(date -u '+%Y' 2>/dev/null)"
rtc_year="${rtc_date%%-*}"

echo "rtc0=${rtc_date} ${rtc_time}" >> "${LOG}"

case "${sys_year}:${rtc_year}" in
    *[!0-9:]*|"")
        echo "result=invalid-year" >> "${LOG}"
        exit 0
        ;;
esac

# Only touch the clock when recovery is obviously wrong. This avoids clobbering
# an already-correct system clock with a stale RTC value.
if [ "${sys_year}" -lt 2020 ] && [ "${rtc_year}" -ge 2020 ] && [ "${rtc_year}" -le 2099 ]; then
    if date -u -s "${rtc_date} ${rtc_time}" >/dev/null 2>&1; then
        echo "result=rtc-applied" >> "${LOG}"
    else
        echo "result=date-set-failed" >> "${LOG}"
    fi
else
    echo "result=no-change" >> "${LOG}"
fi

echo "system_after=$(date -u '+%Y-%m-%d %H:%M:%S UTC' 2>/dev/null)" >> "${LOG}"
