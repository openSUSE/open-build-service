class BinaryRelease < ApplicationRecord
  class SaveError < APIError; end

  # These aliases are the attribute names the backend uses to represent a BinaryRelease
  # Having these makes it easier for us to transpose one into the other.
  alias_attribute :name, :binary_name
  alias_attribute :version, :binary_version
  alias_attribute :release, :binary_release
  alias_attribute :epoch, :binary_epoch
  alias_attribute :binaryarch, :binary_arch
  alias_attribute :binaryid, :binary_id
  alias_attribute :buildtime, :binary_buildtime
  alias_attribute :disturl, :binary_disturl
  alias_attribute :supportstatus, :binary_supportstatus
  alias_attribute :cpeid, :binary_cpeid
  alias_attribute :updateinfoid, :binary_updateinfo
  alias_attribute :updateinfoversion, :binary_updateinfo_version

  belongs_to :repository
  belongs_to :release_package, class_name: 'Package', optional: true
  belongs_to :on_medium, class_name: 'BinaryRelease', optional: true

  before_create :set_release_time

  def set_release_time!
    self.binary_releasetime = Time.now
  end

  # esp. for docker/appliance/python-venv-rpms and friends
  def medium_container
    on_medium.try(:release_package)
  end

  def render_xml
    builder = Nokogiri::XML::Builder.new
    builder.binary(render_attributes) do |binary|
      binary.operation(operation)

      node = {}
      if release_package
        node[:project] = release_package.project.name if release_package.project != repository.project
        node[:package] = release_package.name
      end
      node[:time] = binary_releasetime if binary_releasetime
      node[:flavor] = flavor if flavor
      binary.publish(node) unless node.empty?

      build_node = {}
      build_node[:time] = binary_buildtime if binary_buildtime
      build_node[:binaryid] = binary_id if binary_id
      binary.build(build_node) if build_node.count.positive?
      binary.modify(time: modify_time) if modify_time
      binary.obsolete(time: obsolete_time) if obsolete_time

      binary.binaryid(binary_id) if binary_id
      binary.supportstatus(binary_supportstatus) if binary_supportstatus
      binary.cpeid(binary_cpeid) if binary_cpeid
      binary.updateinfo(id: binary_updateinfo, version: binary_updateinfo_version) if binary_updateinfo
      binary.maintainer(binary_maintainer) if binary_maintainer
      binary.disturl(binary_disturl) if binary_disturl

      update_for_product.each do |up|
        binary.updatefor(up.extend_id_hash(project: up.package.project.name, product: up.name))
      end

      if medium && (medium_package = on_medium.try(:release_package))
        binary.medium(project: medium_package.project.name,
                      package: medium_package.name)
      end

      binary.product(product_medium.product.extend_id_hash(name: product_medium.product.name)) if product_medium
    end
    builder.to_xml(save_with: Nokogiri::XML::Node::SaveOptions::NO_DECLARATION |
                              Nokogiri::XML::Node::SaveOptions::FORMAT)
  end

  def to_axml_id
    builder = Nokogiri::XML::Builder.new
    builder.binary(render_attributes)
    builder.to_xml(save_with: Nokogiri::XML::Node::SaveOptions::NO_DECLARATION |
                              Nokogiri::XML::Node::SaveOptions::FORMAT)
  end

  def to_axml(_opts = {})
    Rails.cache.fetch("xml_binary_release_#{cache_key_with_version}") { render_xml }
  end

  private

  def product_medium
    repository.product_medium.find_by(name: medium)
  end

  # renders all values, which are used as identifier of a binary entry.
  def render_attributes
    attributes = { project: repository.project.name, repository: repository.name }
    %i[binary_name binary_epoch binary_version binary_release binary_arch medium].each do |key|
      value = send(key)
      next unless value

      ekey = key.to_s.gsub(/^binary_/, '')
      attributes[ekey] = value
    end
    attributes
  end

  def set_release_time
    # created_at, but readable in database
    self.binary_releasetime ||= Time.now
  end

  def update_for_product
    repository.product_update_repositories.map(&:product).uniq
  end
end

# == Schema Information
#
# Table name: binary_releases
#
#  id                        :bigint           not null, primary key
#  binary_arch               :string(64)       not null, indexed => [binary_name, binary_epoch, binary_version, binary_release], indexed => [binary_name]
#  binary_buildtime          :datetime
#  binary_cpeid              :string(255)
#  binary_disturl            :string(255)
#  binary_epoch              :string(64)       indexed => [binary_name, binary_version, binary_release, binary_arch]
#  binary_maintainer         :string(255)
#  binary_name               :string(255)      not null, indexed => [binary_epoch, binary_version, binary_release, binary_arch], indexed => [binary_arch], indexed => [repository_id]
#  binary_release            :string(64)       not null, indexed => [binary_name, binary_epoch, binary_version, binary_arch]
#  binary_releasetime        :datetime         not null
#  binary_supportstatus      :string(255)
#  binary_updateinfo         :string(255)      indexed
#  binary_updateinfo_version :string(255)
#  binary_version            :string(64)       not null, indexed => [binary_name, binary_epoch, binary_release, binary_arch]
#  flavor                    :string(255)
#  medium                    :string(255)      indexed
#  modify_time               :datetime
#  obsolete_time             :datetime
#  operation                 :string           default("added")
#  binary_id                 :string(255)      indexed
#  on_medium_id              :bigint
#  release_package_id        :integer          indexed
#  repository_id             :integer          not null, indexed => [binary_name]
#
# Indexes
#
#  exact_search_index                                    (binary_name,binary_epoch,binary_version,binary_release,binary_arch)
#  index_binary_releases_on_binary_id                    (binary_id)
#  index_binary_releases_on_binary_name_and_binary_arch  (binary_name,binary_arch)
#  index_binary_releases_on_binary_updateinfo            (binary_updateinfo)
#  index_binary_releases_on_medium                       (medium)
#  ra_name_index                                         (repository_id,binary_name)
#  release_package_id                                    (release_package_id)
#
# Foreign Keys
#
#  binary_releases_ibfk_1  (repository_id => repositories.id)
#  binary_releases_ibfk_2  (release_package_id => packages.id)
#
