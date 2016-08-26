class StatusHistory < ApplicationRecord
  def self.history_by_key_and_hours(key, hours = 24)
    starttime = Time.now.to_i - hours.to_i * 3600

    where("time >= ? AND \`key\` = ?", starttime, key).
      pluck(:time, :value).
      collect { |time, value| [time.to_i, value.to_f] }
  end
end
