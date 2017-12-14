class BinaryRelease < ApplicationRecord
  #### Includes and extends
  #### Constants
  #### Self config
  class SaveError < APIException; end

  #### Attributes
  #### Associations macros (Belongs to, Has one, Has many)
  belongs_to :repository
  belongs_to :release_package, class_name: 'Package', foreign_key: 'release_package_id' # optional

  #### Callbacks macros: before_save, after_save, etc.
  before_create :set_release_time
  after_rollback :reset_cache
  after_save :reset_cache

  #### Scopes (first the default_scope macro if is used)

  #### Validations macros
  #### Class methods using self. (public and then private)
  def self.update_binary_releases(repository, key, time = Time.now)
    begin
      notification_payload = ActiveSupport::JSON.decode(Backend::Api::Server.notification_payload(key))
    rescue ActiveXML::Transport::NotFoundError
      logger.error("Payload got removed for #{key}")
      return
    end
    update_binary_releases_via_json(repository, notification_payload, time)
    # drop it
    Backend::Api::Server.delete_notification_payload(key)
  end

  def self.update_binary_releases_via_json(repository, json, time = Time.now)
    oldlist = where(repository: repository, obsolete_time: nil, modify_time: nil)
    # we can not just remove it from relation, delete would affect the object.
    processed_item = {}

    BinaryRelease.transaction do
      json.each do |binary|
        # identifier
        hash = { binary_name:    binary['name'],
                 binary_version: binary['version'],
                 binary_release: binary['release'],
                 binary_epoch:   binary['epoch'],
                 binary_arch:    binary['binaryarch'],
                 medium:         binary['medium'],
                 obsolete_time:  nil,
                 modify_time:    nil }
        # check for existing entry
        existing = oldlist.where(hash)
        Rails.logger.info "ERROR: multiple matches, cleaning up: #{existing.inspect}" if existing.count > 1
        # double definition means broken DB entries
        existing.offset(1).destroy_all

        # compare with existing entry
        if existing.count == 1
          entry = existing.first
          if entry.binary_disturl                   == binary['disturl'] &&
             entry.binary_supportstatus             == binary['supportstatus'] &&
             entry.binary_buildtime.to_datetime.utc == ::Time.at(binary['buildtime'].to_i).to_datetime.utc
            # same binary, don't touch
            processed_item[entry.id] = true
            next
          end
          # same binary name and location, but updated content or meta data
          entry.modify_time = time
          entry.save!
          processed_item[entry.id] = true
          hash[:operation] = 'modified' # new entry will get "modified" instead of "added"
        end

        # complete hash for new entry
        hash[:binary_releasetime] = time
        hash[:binary_buildtime] = nil
        hash[:binary_buildtime] = ::Time.at(binary['buildtime'].to_i).to_datetime if binary['buildtime'].to_i > 0
        hash[:binary_disturl] = binary['disturl']
        hash[:binary_supportstatus] = binary['supportstatus']
        if binary['updateinfoid']
          hash[:binary_updateinfo] = binary['updateinfoid']
          hash[:binary_updateinfo_version] = binary['updateinfoversion']
        end
        rp = Package.find_by_project_and_name(binary['project'], binary['package'])
        if binary['project'] && rp
          hash[:release_package_id] = rp.id
        end
        if binary['patchinforef']
          begin
            patchinfo = Patchinfo.new(Backend::Api::Sources::Project.patchinfo(binary['patchinforef']))
          rescue ActiveXML::Transport::NotFoundError
            # patchinfo disappeared meanwhile
          end
          # no database object on purpose, since it must also work for historic releases...
          hash[:binary_maintainer] = patchinfo.to_hash['packager'] if patchinfo && patchinfo.to_hash['packager']
        end

        # new entry, also for modified binaries.
        entry = repository.binary_releases.create(hash)
        processed_item[entry.id] = true
      end

      # and mark all not processed binaries as removed
      oldlist.each do |e|
        next if processed_item[e.id]
        e.obsolete_time = time
        e.save!
        # create an additional "removed" entry here? No one asked for it yet ....
      end
    end
  end

  #### To define class methods as private use private_class_method
  #### private
  #### Instance methods (public and then protected/private)
  def set_release_time!
    self.binary_releasetime = Time.now
  end

  def set_release_time
    # created_at, but readable in database
    self.binary_releasetime ||= Time.now
  end

  def update_for_product
    repository.product_update_repositories.map { |i| i.product if i.product }.uniq
  end

  def product_medium
    repository.product_medium.find_by(name: medium)
  end

  # renders all values, which are used as identifier of a binary entry.
  def render_attributes
    attributes = { project: repository.project.name, repository: repository.name }
    [:binary_name, :binary_epoch, :binary_version, :binary_release, :binary_arch, :medium].each do |key|
      value = send(key)
      next unless value
      ekey = key.to_s.gsub(/^binary_/, '')
      attributes[ekey] = value
    end
    attributes
  end

  def render_xml
    builder = Nokogiri::XML::Builder.new
    builder.binary(render_attributes) do |binary|
      binary.operation operation

      node = {}
      node[:package] = release_package.name if release_package
      node[:time] = self.binary_releasetime if self.binary_releasetime
      binary.publish(node) unless node.empty?

      binary.build(time: binary_buildtime) if binary_buildtime
      binary.modify(time: modify_time) if modify_time
      binary.obsolete(time: obsolete_time) if obsolete_time

      binary.supportstatus binary_supportstatus if binary_supportstatus
      binary.updateinfo(id: binary_updateinfo, version: binary_updateinfo_version) if binary_updateinfo
      binary.maintainer binary_maintainer if binary_maintainer
      binary.disturl binary_disturl if binary_disturl

      update_for_product.each do |up|
        binary.updatefor(up.extend_id_hash(project: up.package.project.name, product: up.name))
      end

      if product_medium
        binary.product(product_medium.product.extend_id_hash(name: product_medium.product.name))
      end
    end
    builder.to_xml save_with: Nokogiri::XML::Node::SaveOptions::NO_DECLARATION |
                              Nokogiri::XML::Node::SaveOptions::FORMAT
  end

  def to_axml_id
    builder = Nokogiri::XML::Builder.new
    builder.binary(render_attributes)
    builder.to_xml save_with: Nokogiri::XML::Node::SaveOptions::NO_DECLARATION |
                              Nokogiri::XML::Node::SaveOptions::FORMAT
  end

  def to_axml(_opts = {})
    Rails.cache.fetch("xml_binary_release_#{cache_key}") { render_xml }
  end

  def reset_cache
    Rails.cache.delete("xml_binary_release_#{cache_key}")
  end

  #### Alias of methods
end

# == Schema Information
#
# Table name: binary_releases
#
#  id                        :integer          not null, primary key
#  repository_id             :integer          not null, indexed => [binary_name]
#  operation                 :string(8)        default("added")
#  obsolete_time             :datetime
#  release_package_id        :integer          indexed
#  binary_name               :string(255)      not null, indexed => [binary_epoch, binary_version, binary_release, binary_arch], indexed => [binary_arch], indexed => [repository_id]
#  binary_epoch              :string(64)       indexed => [binary_name, binary_version, binary_release, binary_arch]
#  binary_version            :string(64)       not null, indexed => [binary_name, binary_epoch, binary_release, binary_arch]
#  binary_release            :string(64)       not null, indexed => [binary_name, binary_epoch, binary_version, binary_arch]
#  binary_arch               :string(64)       not null, indexed => [binary_name, binary_epoch, binary_version, binary_release], indexed => [binary_name]
#  binary_disturl            :string(255)
#  binary_buildtime          :datetime
#  binary_releasetime        :datetime         not null
#  binary_supportstatus      :string(255)
#  binary_maintainer         :string(255)
#  medium                    :string(255)      indexed
#  binary_updateinfo         :string(255)      indexed
#  binary_updateinfo_version :string(255)
#  modify_time               :datetime
#
# Indexes
#
#  exact_search_index                                    (binary_name,binary_epoch,binary_version,binary_release,binary_arch)
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
