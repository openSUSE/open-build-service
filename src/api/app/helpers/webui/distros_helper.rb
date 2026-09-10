module Webui::DistrosHelper
  def calculate_year_fraction(date)
    date.year + (date.yday.to_f / 365.25)
  end

  def timeline_rows_for(distro)
    distro.distro_releases.includes(:distro_release_lifecycles).filter_map do |distro_release|
      sorted_lifecycles = distro_release.distro_release_lifecycles.chronological
      next if sorted_lifecycles.empty?

      intervals = sorted_lifecycles.each_cons(2).map do |current_lifecycle, next_lifecycle|
        {
          title: current_lifecycle.name,
          start_date: current_lifecycle.date,
          end_date: next_lifecycle.date
        }
      end

      latest_lifecycle = sorted_lifecycles.last
      intervals << {
        title: latest_lifecycle.name,
        start_date: latest_lifecycle.date,
        end_date: latest_lifecycle.date + 1.day,
        injected: true
      }

      {
        title: distro_release.name,
        intervals: intervals
      }
    end
  end

  def prepare_timeline_data(rows)
    return { rows: [], any_dates: false } if rows.blank?

    all_interval_dates = extract_all_interval_dates(rows)
    return { rows: [], any_dates: false } if all_interval_dates.empty?

    minimum_year = all_interval_dates.map(&:year).min
    maximum_year = all_interval_dates.map(&:year).max
    total_years = [maximum_year - minimum_year + 1, 1].max

    repeating_gradient = 'repeating-linear-gradient(to right, transparent 0%, ' \
                         "transparent calc(100% / #{total_years} - 1px), " \
                         "var(--border) calc(100% / #{total_years} - 1px), " \
                         "var(--border) calc(100% / #{total_years}))"

    processed_rows = rows.map { |row| process_timeline_row(row, minimum_year, total_years) }

    {
      rows: processed_rows,
      minimum_year: minimum_year,
      maximum_year: maximum_year,
      repeating_gradient: repeating_gradient,
      any_dates: true
    }
  end

  private

  def extract_all_interval_dates(rows)
    rows.flat_map do |row|
      row[:intervals].flat_map { |interval| extract_interval_dates(interval) }
    end.compact
  end

  def extract_interval_dates(interval)
    if interval[:injected]
      [interval[:start_date]]
    else
      [interval[:start_date], interval[:end_date]]
    end
  end

  def process_timeline_row(row, minimum_year, total_years)
    processed_intervals = row[:intervals].map do |interval|
      start_year_fraction = calculate_year_fraction(interval[:start_date])
      end_year_fraction = calculate_year_fraction(interval[:end_date])

      left_percentage = ((start_year_fraction - minimum_year) / total_years * 100).clamp(0.0, 100.0)
      max_width = [100.0 - left_percentage, 0.5].max
      width_percentage = ((end_year_fraction - start_year_fraction) / total_years * 100).clamp(0.5, max_width)

      interval.merge(
        left_pct: left_percentage,
        width_pct: width_percentage
      )
    end
    row.merge(intervals: processed_intervals)
  end
end
