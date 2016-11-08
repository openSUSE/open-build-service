class IncidentUpdateinfoCounterValue < ApplicationRecord
  belongs_to :updateinfo_counter
  belongs_to :project

  def self.find_or_create(time, updateinfo_counter, project)
    icv = IncidentUpdateinfoCounterValue.find_by(updateinfo_counter: updateinfo_counter, project: project)
    return icv if icv

    # not yet released, get an uniq counter value for this incident and scheme
    IncidentUpdateinfoCounterValue.create(released_at: time,
                                          updateinfo_counter:updateinfo_counter,
                                          project: project,
                                          value: updateinfo_counter.increase)
  end
end
