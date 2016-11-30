class UpdateinfoCounter < ApplicationRecord
  def self.find_or_create(time, template)
    year  = time.year  if template =~ /%Y/
    month = time.month if template =~ /%M/
    day   = time.day   if template =~ /%D/

    UpdateinfoCounter.find_or_create_by(year: year, month: month, day: day)
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
    counter
  end
end
