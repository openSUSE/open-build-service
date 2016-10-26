class UpdateinfoCounter < ApplicationRecord
  def self.find_or_create(time, template)
    year = month = day = nil

    year  = time.year  if template =~ /%Y/
    month = time.month if template =~ /%M/
    day   = time.day   if template =~ /%D/

    r = UpdateinfoCounter.where(year: year, month: month, day: day).first
    r = UpdateinfoCounter.create(year: year, month: month, day: day) unless r

    r
  end

  def increase
    # do an atomic increase of counter
    counter = nil
    transaction do
      lock!
      increment!(:counter)
      counter = self.counter
      save!
    end
    return counter
  end
end
