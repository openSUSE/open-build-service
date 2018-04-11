# frozen_string_literal: true

class IncidentUpdateinfoCounterValue < ApplicationRecord
  belongs_to :updateinfo_counter
  belongs_to :project

  def self.find_or_create(time, updateinfo_counter, project)
    icv = IncidentUpdateinfoCounterValue.find_by(updateinfo_counter: updateinfo_counter, project: project)
    return icv if icv

    # not yet released, get an uniq counter value for this incident and scheme
    IncidentUpdateinfoCounterValue.create(released_at: time,
                                          updateinfo_counter: updateinfo_counter,
                                          project: project,
                                          value: updateinfo_counter.increase)
  end
end

# == Schema Information
#
# Table name: incident_updateinfo_counter_values
#
#  id                    :integer          not null, primary key
#  updateinfo_counter_id :integer          not null, indexed => [project_id]
#  project_id            :integer          not null, indexed, indexed => [updateinfo_counter_id]
#  value                 :integer          not null
#  released_at           :datetime         not null
#
# Indexes
#
#  project_id     (project_id)
#  uniq_id_index  (updateinfo_counter_id,project_id)
#
# Foreign Keys
#
#  incident_updateinfo_counter_values_ibfk_1  (project_id => projects.id)
#
