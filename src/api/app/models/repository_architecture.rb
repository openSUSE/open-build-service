class RepositoryArchitecture < ApplicationRecord
  serialize :required_checks, Array
  belongs_to :repository,   inverse_of: :repository_architectures
  belongs_to :architecture, inverse_of: :repository_architectures

  acts_as_list scope: [:repository_id], top_of_list: 0

  validates :repository, :architecture, :position, presence: true
  validates :repository, uniqueness: { scope: :architecture }

  has_many :status_reports, as: :checkable, class_name: 'Status::Report', dependent: :destroy

  def build_id
    Backend::Api::Build::Repository.build_id(repository.project.name, repository.name, architecture.name)
  end
end

# == Schema Information
#
# Table name: repository_architectures
#
#  repository_id   :integer          not null, indexed => [architecture_id]
#  architecture_id :integer          not null, indexed => [repository_id], indexed
#  position        :integer          default(0), not null
#  id              :integer          not null, primary key
#
# Indexes
#
#  arch_repo_index  (repository_id,architecture_id) UNIQUE
#  architecture_id  (architecture_id)
#
# Foreign Keys
#
#  repository_architectures_ibfk_1  (repository_id => repositories.id)
#  repository_architectures_ibfk_2  (architecture_id => architectures.id)
#
