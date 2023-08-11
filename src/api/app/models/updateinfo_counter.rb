class UpdateinfoCounter < ApplicationRecord
  def self.find_or_create(time, maintenance_project, template)
    year  = time.year  if template =~ /%Y/
    month = time.month if template =~ /%M/
    day   = time.day   if template =~ /%D/

    # fix broken database entries without a defined maintenance project
    # it used to be broken from 2015-2022
    if (uc = UpdateinfoCounter.find_by(maintenance_db_project_id: nil, year: year, month: month, day: day))
      uc.maintenance_db_project_id = maintenance_project.id
      uc.save
    end

    UpdateinfoCounter.find_or_create_by(maintenance_db_project_id: maintenance_project.id, year: year, month: month, day: day)
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
