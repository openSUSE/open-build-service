class MaintainedProject < ApplicationRecord
  belongs_to :project, foreign_key: :project_id
  belongs_to :maintenance_project, class_name: "Project", foreign_key: :maintenance_project_id
end

# == Schema Information
#
# Table name: maintained_projects
#
#  id                     :integer          not null, primary key
#  project_id             :integer          not null
#  maintenance_project_id :integer          not null
#
# Indexes
#
#  maintenance_project_id  (maintenance_project_id)
#  uniq_index              (project_id,maintenance_project_id) UNIQUE
#
