class RepositoryArchitecture < ApplicationRecord
  include Status::Checkable

  belongs_to :repository,   inverse_of: :repository_architectures
  belongs_to :architecture, inverse_of: :repository_architectures

  acts_as_list scope: [:repository_id], top_of_list: 0

  validates :repository, :architecture, :position, presence: true
  validates :repository, uniqueness: { scope: :architecture }

  def build_id
    Backend::Api::Build::Repository.build_id(repository.project.name, repository.name, architecture.name)
  end
end

# == Schema Information
#
# Table name: repository_architectures
#
#  id              :integer          not null, primary key
#  position        :integer          default(0), not null
#  required_checks :string(255)
#  architecture_id :integer          not null, indexed => [repository_id], indexed
#  repository_id   :integer          not null, indexed => [architecture_id]
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
