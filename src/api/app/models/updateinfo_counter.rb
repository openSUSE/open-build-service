class UpdateinfoCounter < ApplicationRecord
  def self.find_or_create(time, template)
    year  = time.year  if template.include?('%Y')
    month = time.month if template.include?('%M')
    day   = time.day   if template.include?('%D')

    UpdateinfoCounter.find_or_create_by(year: year, month: month, day: day)
  end

  def increase
    # do an atomic increase of counter
    transaction do
      lock!
      increment(:counter)
      save!
    end
    counter
  end
end

# == Schema Information
#
# Table name: updateinfo_counters
#
#  id                        :integer          not null, primary key
#  counter                   :integer          default(0)
#  day                       :integer
#  month                     :integer
#  year                      :integer
#  maintenance_db_project_id :integer
#
