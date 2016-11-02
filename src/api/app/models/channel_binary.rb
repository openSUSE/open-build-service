class ChannelBinary < ApplicationRecord
  belongs_to :channel_binary_list
  belongs_to :project
  belongs_to :repository
  belongs_to :architecture

  validate do |channel_binary|
    if channel_binary.project && channel_binary.repository
      unless channel_binary.repository.project == channel_binary.project
        errors.add_to_base("Associated project has to match with repository.project")
      end
    end
  end

  def self._sync_keys
    [ :name, :project, :repository, :architecture, :package, :binaryarch ]
  end

  def self.find_by_project_and_package(project, package)
    project = Project.find_by_name(project) if project.is_a? String

    # find maintained projects filter
    maintained_projects = Project.get_maintenance_project.expand_maintained_projects

    # gsub(/\s+/, "") makes sure there are no additional newlines and whitespaces
    query = <<-SQL.gsub(/\s+/, " ")
      SELECT channel_binaries.* FROM channel_binaries
        LEFT JOIN channel_binary_lists ON channel_binary_lists.id = channel_binaries.channel_binary_list_id
          LEFT JOIN channels ON channel_binary_lists.channel_id = channels.id
            LEFT JOIN packages ON channels.package_id = packages.id WHERE (
              channel_binary_lists.project_id = ? and package = ? and packages.project_id IN (?)
            )
    SQL
    ChannelBinary.find_by_sql([query, project.id, package, maintained_projects])
  end

  def create_channel_package_into(project, comment = nil)
    channel = channel_binary_list.channel
    package_exists = Package.exists_by_project_and_name(project.name, channel.name,
                                                        follow_project_links: false,
                                                        allow_remote_packages: false
                                                       )
    # does it exist already? then just skip it
    unless package_exists
      # create a channel package beside my package and return that
      channel.branch_channel_package_into_project(project, comment)
    end
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
      c.binary(binary_data)

      # report target repository and products using it.
      if options[:include_channel_targets]
        channel.channel_targets.each do |channel_target|
          create_channel_node_element(c, channel_target)
        end
      end
    end

    builder.to_xml save_with: Nokogiri::XML::Node::SaveOptions::NO_DECLARATION |
                                 Nokogiri::XML::Node::SaveOptions::FORMAT
  end

  def create_channel_node_element(channel_node, channel_target)
    attributes = {
      project:    channel_target.repository.project.name,
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
