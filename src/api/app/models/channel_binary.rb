class ChannelBinary < ApplicationRecord
  belongs_to :channel_binary_list
  belongs_to :project, optional: true
  belongs_to :repository, optional: true
  belongs_to :architecture, optional: true

  validates :supportstatus, length: { maximum: 255 }
  validates :superseded_by, length: { maximum: 255 }

  validate do |channel_binary|
    errors.add(:base, :invalid, message: 'Associated project has to match with repository.project') if channel_binary.project && channel_binary.repository && !(channel_binary.repository.project == channel_binary.project)
  end

  def self._sync_keys
    %i[name project repository architecture package binaryarch]
  end

  def self.find_by_project_and_package(project, package)
    project = Project.find_by_name(project) if project.is_a?(String)

    # find maintained projects filter
    maintained_projects = Project.get_maintenance_project!.expand_maintained_projects

    # gsub(/\s+/, "") makes sure there are no additional newlines and whitespaces
    query = <<-SQL.squish.gsub(/\s+/, ' ')
      SELECT channel_binaries.* FROM channel_binaries
        LEFT JOIN channel_binary_lists ON channel_binary_lists.id = channel_binaries.channel_binary_list_id
          LEFT JOIN channels ON channel_binary_lists.channel_id = channels.id
            LEFT JOIN packages ON channels.package_id = packages.id WHERE (
              channel_binary_lists.project_id = ? and package = ? and packages.project_id IN (?)
            )
    SQL
    ChannelBinary.find_by_sql([query, project.id, Package.striping_multibuild_suffix(package), maintained_projects])
  end

  def create_channel_package_into(project, comment = nil)
    channel = channel_binary_list.channel
    package_exists = Package.exists_by_project_and_name(project.name, channel.name,
                                                        follow_project_links: false)
    # does it exist already? then just skip it
    # create a channel package beside my package and return that
    channel.branch_channel_package_into_project(project, comment) unless package_exists
  end

  def to_axml_id(_opts = {})
    Rails.cache.fetch("xml_channel_binary_id_#{id}") do
      create_xml
    end
  end

  def to_axml(_opts = {})
    Rails.cache.fetch("xml_channel_binary_#{id}") do
      create_xml(include_channel_targets: true)
    end
  end

  private

  # Creates an xml builder object for all binaries
  # rubocop:disable Metrics/PerceivedComplexity
  def create_xml(options = {})
    channel = channel_binary_list.channel

    builder = Nokogiri::XML::Builder.new
    attributes = {
      project: channel.package.project.name,
      package: channel.package.name
    }
    builder.channel(attributes) do |c|
      binary_data = { name: name }
      binary_data[:project]       = channel_binary_list.project.name if channel_binary_list.project
      binary_data[:project]       = project.name  if project
      binary_data[:package]       = package       if package
      binary_data[:binaryarch]    = binaryarch    if binaryarch
      binary_data[:supportstatus] = supportstatus if supportstatus
      binary_data[:superseded_by] = superseded_by if superseded_by
      c.binary(binary_data)

      # report target repository and products using it.
      if options[:include_channel_targets]
        channel.channel_targets.each do |channel_target|
          create_channel_node_element(c, channel_target)
        end
      end
    end

    builder.to_xml(save_with: Nokogiri::XML::Node::SaveOptions::NO_DECLARATION |
                              Nokogiri::XML::Node::SaveOptions::FORMAT)
  end
  # rubocop:enable Metrics/PerceivedComplexity

  def create_channel_node_element(channel_node, channel_target)
    attributes = {
      project: channel_target.repository.project.name,
      repository: channel_target.repository.name
    }
    channel_node.target(attributes) do |target|
      target.disabled if channel_target.disabled
      channel_target.repository.product_update_repositories.each do |up|
        attributes = {
          project: up.product.package.project.name,
          product: up.product.name
        }
        target.updatefor(up.product.extend_id_hash(attributes))
      end
    end
  end
end

# == Schema Information
#
# Table name: channel_binaries
#
#  id                     :integer          not null, primary key
#  binaryarch             :string(255)
#  name                   :string(255)      not null, indexed => [channel_binary_list_id]
#  package                :string(255)      indexed => [project_id]
#  supportstatus          :string(255)
#  superseded_by          :string(255)
#  architecture_id        :integer          indexed
#  channel_binary_list_id :integer          not null, indexed, indexed => [name]
#  project_id             :integer          indexed => [package]
#  repository_id          :integer          indexed
#
# Indexes
#
#  architecture_id                                            (architecture_id)
#  channel_binary_list_id                                     (channel_binary_list_id)
#  index_channel_binaries_on_name_and_channel_binary_list_id  (name,channel_binary_list_id)
#  index_channel_binaries_on_project_id_and_package           (project_id,package)
#  repository_id                                              (repository_id)
#
# Foreign Keys
#
#  channel_binaries_ibfk_1  (channel_binary_list_id => channel_binary_lists.id)
#  channel_binaries_ibfk_2  (project_id => projects.id)
#  channel_binaries_ibfk_3  (repository_id => repositories.id)
#  channel_binaries_ibfk_4  (architecture_id => architectures.id)
#
