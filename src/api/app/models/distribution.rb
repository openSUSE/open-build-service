class Distribution < ApplicationRecord
  validates :vendor, :version, :name, :reponame, :repository, :project, presence: true

  has_and_belongs_to_many :icons, -> { distinct }, class_name: 'DistributionIcon'
  has_and_belongs_to_many :architectures, -> { distinct }, class_name: 'Architecture'

  scope :local, -> { where(remote: false) }
  scope :remote, -> { where(remote: true) }
  scope :for_project, ->(project_name) { where('project like ?', "#{project_name}:%") }

  def self.new_from_xmlhash(xmlhash)
    return new unless xmlhash.is_a?(Xmlhash::XMLHash)

    distribution = Distribution.new(xmlhash.except('architecture', 'icon', 'id')
                                           .merge(architectures: Architecture.where(name: xmlhash['architecture'])))
    xmlhash.elements('icon') do |icon|
      distribution.icons.new(icon)
    end

    distribution
  end

  def update_from_xmlhash(xmlhash)
    return unless xmlhash.is_a?(Xmlhash::XMLHash)

    update(xmlhash.except('id', 'architecture', 'icon'))

    architectures.clear
    xmlhash.elements('architecture') do |architecture_name|
      architecture = Architecture.find_by(name: architecture_name)
      architectures << architecture if architecture
    end

    icons.clear
    xmlhash.elements('icon') do |icon|
      icons.create(icon)
    end

    self
  end
end

# == Schema Information
#
# Table name: distributions
#
#  id         :integer          not null, primary key
#  link       :string(255)
#  name       :string(255)      not null
#  project    :string(255)      not null
#  remote     :boolean          default(FALSE)
#  reponame   :string(255)      not null
#  repository :string(255)      not null
#  vendor     :string(255)      not null
#  version    :string(255)      not null
#
