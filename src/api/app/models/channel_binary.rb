class ChannelBinary < ActiveRecord::Base

  belongs_to :channel_binary_list
  belongs_to :project
  belongs_to :repository
  belongs_to :architecture

  def self._sync_keys
    [ :name, :project, :repository, :architecture, :package, :binaryarch ]
  end

  def self.find_by_project_and_package(project, package)
    project = Project.find_by_name(project) if project.is_a? String

    # find maintained projects filter
    maintained_projects = Project.get_maintenance_project.expand_maintained_projects

    # I am not able to construct this with rails in a valid way :/
    ChannelBinary.find_by_sql(['SELECT channel_binaries.* FROM channel_binaries LEFT JOIN channel_binary_lists ON channel_binary_lists.id = channel_binaries.channel_binary_list_id LEFT JOIN channels ON channel_binary_lists.channel_id = channels.id LEFT JOIN packages ON channels.package_id = packages.id WHERE (channel_binary_lists.project_id = ? and package = ? and packages.project_id IN (?))', project.id, package, maintained_projects])
  end

  def create_channel_package_into(project)

    channel = self.channel_binary_list.channel

    # does it exist already? then just skip it
    return nil if Package.exists_by_project_and_name(project.name, channel.name, follow_project_links: false, allow_remote_packages: false)

    # create a channel package beside my package and return that
    return channel.branch_channel_package_into_project(project)
  end

  def to_axml_id(opts={})
    Rails.cache.fetch('xml_channel_binary_id_%d' % id) do
      channel = channel_binary_list.channel
      builder = Nokogiri::XML::Builder.new
      builder.channel(project: channel.package.project.name, package: channel.package.name) do |c|
        p={}
        p[:package] = package if package
        p[:name] = name if name
        p[:binaryarch] = binaryarch if binaryarch
        p[:supportstatus] = supportstatus if supportstatus
        next unless p.length > 0
        c.binary(p)
      end
      builder.to_xml :save_with => Nokogiri::XML::Node::SaveOptions::NO_DECLARATION |
                                   Nokogiri::XML::Node::SaveOptions::FORMAT
    end
  end

  def to_axml(opts={})
    Rails.cache.fetch('xml_channel_binary_%d' % id) do
      channel = channel_binary_list.channel
      builder = Nokogiri::XML::Builder.new
      builder.channel(project: channel.package.project.name, package: channel.package.name) do |c|
        p={}
        p[:package] = package if package
        p[:name] = name if name
        p[:binaryarch] = binaryarch if binaryarch
        p[:supportstatus] = supportstatus if supportstatus
        next unless p.length > 0
        c.binary(p)

        # report target repository and products using it.
        channel.channel_targets.each do |ct|
          c.target(project: ct.repository.project.name, repository: ct.repository.name) do |target|
            target.disabled() if ct.disabled
            ct.repository.product_update_repositories.each do |up|
              target.updatefor(up.product.extend_id_hash({project: up.product.package.project.name, product: up.product.name}))
            end
          end
        end

      end
      builder.to_xml :save_with => Nokogiri::XML::Node::SaveOptions::NO_DECLARATION |
                                   Nokogiri::XML::Node::SaveOptions::FORMAT
    end
  end

end
