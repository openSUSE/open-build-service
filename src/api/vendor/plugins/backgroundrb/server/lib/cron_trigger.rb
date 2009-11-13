module BackgrounDRb
  class CronTrigger
    WDAYS = { 0 => "Sunday",1 => "Monday",2 => "Tuesday",3 => "Wednesday", 4 => "Thursday", 5 => "Friday", 6 => "Saturday" }
    LeapYearMonthDays = [31, 29, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31]
    CommonYearMonthDays = [31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31]

    attr_reader :sec, :min, :hour, :day, :month, :wday, :year, :cron_expr

    # initialize the Cron Trigger
    def initialize(expr)
      self.cron_expr = expr
    end

    # create the cron expression and populate instance variables.
    def cron_expr=(expr)
      @cron_expr = expr
      self.sec, self.min, self.hour, self.day, self.month, self.wday, self.year = @cron_expr.split(' ')
    end

    def fire_after_time(p_time)
      @t_sec,@t_min,@t_hour,@t_day,@t_month,@t_year,@t_wday,@t_yday,@t_idst,@t_zone = p_time.to_a
      @count = 0
      loop do
        @count += 1

        if @year && !@year.include?(@t_year)
          return nil if @t_year > @year.max
          @t_year = @year.detect { |y| y > @t_year }
        end

        # if range of months doesn't include current month, find next month from the range
        unless @month.include?(@t_month)
          next_month = @month.detect { |m| m > @t_month } || @month.min
          @t_day,@t_hour,@t_min,@t_sec = @day.min,@hour.min,@min.min,@sec.min
          if next_month < @t_month
            @t_month = next_month
            @t_year += 1
            retry
          end
          @t_month = next_month
        end

        if !day_restricted? && wday_restricted?
          unless @wday.include?(@t_wday)
            next_wday = @wday.detect { |w| w > @t_wday} || @wday.min
            @t_hour,@t_min,@t_sec = @hour.min,@min.min,@sec.min
            t_time = Chronic.parse("next #{WDAYS[next_wday]}",:now => current_time)
            @t_day,@t_month,@t_year = t_time.to_a[3..5]
            @t_wday = next_wday
            retry
          end
        elsif !wday_restricted? && day_restricted?
          day_range = (1.. month_days(@t_year,@t_month))
          # day array, that includes days which are present in current month
          day_array = @day.select { |d| day_range === d }
          unless day_array.include?(@t_day)
            next_day = day_array.detect { |d| d > @t_day } || day_array.min
            @t_hour,@t_min,@t_sec = @hour.min,@min.min,@sec.min
            if !next_day || next_day < @t_day
              t_time = Chronic.parse("next month",:now => current_time)
              @t_day = next_day.nil? ? @day.min : next_day
              @t_month,@t_year = t_time.month,t_time.year
              retry
            end
            @t_day = next_day
          end
        else
          # if both day and wday are restricted cron should give preference to one thats closer to current time
          day_range = (1 .. month_days(@t_year,@t_month))
          day_array = @day.select { |d| day_range === d }
          if !day_array.include?(@t_day) && !@wday.include?(@t_wday)
            next_day = day_array.detect { |d| d > @t_day } || day_array.min
            next_wday = @wday.detect { |w| w > @t_wday } || @wday.min
            @t_hour,@t_min,@t_sec = @hour.min,@min.min,@sec.min

            # if next_day is nil or less than @t_day it means that it should run in next month
            if !next_day || next_day < @t_day
              next_time_mday = Chronic.parse("next month",:now => current_time)
            else
              @t_day = next_day
              next_time_mday = current_time
            end
            next_time_wday = Chronic.parse("next #{WDAYS[next_wday]}",:now => current_time)
            if next_time_mday < next_time_wday
              @t_day,@t_month,@t_year = next_time_mday.to_a[3..5]
            else
              @t_day,@t_month,@t_year = next_time_wday.to_a[3..5]
            end
            retry
          end
        end

        unless @hour.include?(@t_hour)
          next_hour = @hour.detect { |h| h > @t_hour } || @hour.min
          @t_min,@t_sec = @min.min,@sec.min
          if next_hour < @t_hour
            @t_hour = next_hour
            next_day = Chronic.parse("next day",:now => current_time)
            @t_day,@t_month,@t_year,@t_wday = next_day.to_a[3..6]
            retry
          end
          @t_hour = next_hour
        end

        unless @min.include?(@t_min)
          next_min = @min.detect { |m| m > @t_min } || @min.min
          @t_sec = @sec.min
          if next_min < @t_min
            @t_min = next_min
            next_hour = Chronic.parse("next hour",:now => current_time)
            @t_hour,@t_day,@t_month,@t_year,@t_wday = next_hour.to_a[2..6]
            retry
          end
          @t_min = next_min
        end

        unless @sec.include?(@t_sec)
          next_sec = @sec.detect { |s| s > @t_sec } || @sec.min
          if next_sec < @t_sec
            @t_sec = next_sec
            next_min = Chronic.parse("next minute",:now => current_time)
            @t_min,@t_hour,@t_day,@t_month,@t_year,@t_wday = next_min.to_a[1..6]
            retry
          end
          @t_sec = next_sec
        end
        break
      end # end of loop do
      current_time
    end

    def current_time
      Time.local(@t_sec,@t_min,@t_hour,@t_day,@t_month,@t_year,@t_wday,nil,@t_idst,@t_zone)
    end

    def day_restricted?
      return !@day.eql?(1..31)
    end

    def wday_restricted?
      return !@wday.eql?(0..6)
    end

    # TODO: mimic attr_reader to define all of these
    def sec=(sec); @sec = parse_part(sec, 0 .. 59); end

    def min=(min); @min = parse_part(min, 0 .. 59); end

    def hour=(hour); @hour = parse_part(hour, 0 .. 23); end

    def day=(day)
      @day = parse_part(day, 1 .. 31)
    end

    def month=(month)
      @month = parse_part(month, 1 .. 12)
    end

    def year=(year)
      @year = parse_part(year)
    end

    def wday=(wday)
      @wday = parse_part(wday, 0 .. 6)
    end
    private
    def month_days(y, m)
      if ((y % 4 == 0) && (y % 100 != 0)) || (y % 400 == 0)
        LeapYearMonthDays[m-1]
      else
        CommonYearMonthDays[m-1]
      end
    end

    # 0-5,8,10; 0-5; *; */5
    def parse_part(part, range=nil)
      return range  if part.nil? or part == '*' or part =~ /^[*0]\/1$/

      r = Array.new
      part.split(',').each do |p|
        if p =~ /-/  # 0-5
          r << Range.new(*(p.scan(/\d+/).map { |x| x.to_i })).map { |x| x.to_i }
        elsif p =~ /(\*|\d+)\/(\d+)/ && range  # */5, 2/10
          min = $1 == '*' ? 0 : $1.to_i
          inc = $2.to_i
          (min .. range.end).each_with_index do |x, i|
            r << (range.begin == 1 ? x + 1 : x) if i % inc == 0
          end
        else
          r << p.to_i
        end
      end
      r.flatten
    end
  end
end

