# © 2026 aiaiaiai · aiaiaiai.org
# SPDX-License-Identifier: Apache-2.0

require "time"

module PrismPorter
  module Presentation
    # Wall-clock time in Ukraine, from a UTC instant, without a time zone database.
    #
    # Ukraine follows the EU rule: UTC+2, and UTC+3 from 01:00 UTC on the last Sunday of March
    # until 01:00 UTC on the last Sunday of October. The offset is computed, so the same instant
    # always renders the same text on any machine.
    module KyivTime
      module_function

      def clock(utc)
        (utc.utc + (offset_hours(utc) * 3600)).strftime("%H:%M")
      end

      def offset_hours(utc)
        utc = utc.utc
        summer = utc >= last_sunday(utc.year, 3) && utc < last_sunday(utc.year, 10)
        summer ? 3 : 2
      end

      def last_sunday(year, month)
        day = Time.utc(year, month, 31, 1)
        day - (day.wday * 86_400)
      end
    end
  end
end
