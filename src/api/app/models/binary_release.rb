class BinaryRelease < ActiveRecord::Base

  belongs_to :repository

  # optional
  belongs_to :release_package, :class_name => "Package", foreign_key: "release_package_id"

  before_create :set_release_time

  def set_release_time
    # created_at, but readable in database
    self.binary_releasetime = Time.now
  end

  class << self
    def find_by_repo_and_name( repo, name )
      self.where(:repository => repo, :binary_name => name)
    end
    def get_all_current_binaries( repo )
      self.where(:repository => repo, :obsolete_time => nil)
    end
  end

  def used_in_products
    # check if any product is referencing the repository where this binary lives
    products = []
    # add products only when they have the binary on a media
    products += ProductMedium.where( :repository => repository, :medium => medium ).map{ |i| i.product if i.product } if medium
    # add products if they use the update channel
    products += ProductUpdateRepository.where( :repository => repository ).map{ |i| i.product if i.product }
    products.uniq
  end

  def render_attributes
    p = { :project    => repository.project.name,
          :repository => repository.name,
        }
    [ :binary_name, :binary_epoch, :binary_version, :binary_release, :binary_arch, :medium ].each do |key|
      value = self.send(key)
      next unless value
      ekey = key.to_s.gsub(/^binary_/, '')
      p[ekey] = value
    end
    return p
  end

  def render_xml
    builder = Nokogiri::XML::Builder.new
    builder.binary(render_attributes) do |b|
      r={}
      b.operation self.operation
      if self.release_package
#        r[:project] = self.release_package.project.name # pointless, it is our binary project
        r[:package] = self.release_package.name
      end
      r[:time] = self.binary_releasetime if self.binary_releasetime
      b.release(r) if r.length > 0

      b.build(:time => self.binary_buildtime) if self.binary_buildtime

      b.obsolete(:time => self.obsolete_time) if self.obsolete_time

      b.supportstatus self.binary_supportstatus if self.binary_supportstatus
      if self.binary_updateinfo
        b.updateinfo( { :id => self.binary_updateinfo, :version => self.binary_updateinfo_version } )
      end
      b.maintainer self.binary_maintainer if self.binary_maintainer
      b.disturl self.binary_disturl if self.binary_disturl

      b.products do |p|
         self.used_in_products.each do |product|
           p.product( :project => product.package.project.name, :name => product.name )
         end
      end if self.used_in_products.length > 0
    end
    builder.to_xml :save_with => Nokogiri::XML::Node::SaveOptions::NO_DECLARATION |
                                 Nokogiri::XML::Node::SaveOptions::FORMAT
  end

  def to_axml_id
    builder = Nokogiri::XML::Builder.new
    builder.binary(render_attributes)
    builder.to_xml :save_with => Nokogiri::XML::Node::SaveOptions::NO_DECLARATION |
                                 Nokogiri::XML::Node::SaveOptions::FORMAT
  end

  def to_axml
    Rails.cache.fetch('xml_binary_release_%d' % id) do
      render_xml
    end
  end

  after_rollback :reset_cache
  after_save :reset_cache

  def reset_cache
    Rails.cache.delete('xml_binary_release_%d' % id)
  end

  def self.update_binary_releases(repository, key, time = Time.now)
    begin
      body = Suse::Backend.get("/notificationpayload/#{key}").body
      pt = ActiveSupport::JSON.decode(body)
    rescue ActiveXML::Transport::NotFoundError
      logger.error("Payload got removed for #{key}")
      return
    end
    update_binary_releases_via_json(repository, pt, time)
    # drop it 
    Suse::Backend.delete("/notificationpayload/#{key}")
  end

  def self.update_binary_releases_via_json(repository, json, time = Time.now)
    oldlist = get_all_current_binaries(repository)
    processed_item = {} # we can not just remove it from relation
                        # delete would affect the object

    BinaryRelease.transaction do
      json.each do |binary|
        # identifier
        hash={ :binary_name => binary["name"],
               :binary_version => binary["version"],
               :binary_release => binary["release"],
               :binary_epoch => binary["epoch"],
               :binary_arch => binary["binaryarch"],
               :medium => binary["medium"],
               :obsolete_time => nil
             }
        # check for existing entry
        existing = oldlist.where(hash)
        raise SaveError if existing.count > 1
        
        # compare with existing entry
        if existing.count == 1
          entry = existing.first
          if entry.binary_disturl       == binary["disturl"] and
             entry.binary_supportstatus == binary["supportstatus"] and
             entry.binary_buildtime.utc == ::Time.at(binary["buildtime"].to_i).to_datetime.utc
             # same binary, don't touch
             processed_item[entry.id] = true
             next
          end
          # same binary name and location, but different content
          entry.obsolete_time = time
          entry.save!
          processed_item[entry.id] = true
          hash[:operation] = "modified" # new entry will get "modified" instead of "added"
        end

        # complete hash for new entry
        hash[:binary_releasetime] = time
        hash[:binary_buildtime] = nil
        hash[:binary_buildtime] = ::Time.at(binary["buildtime"].to_i).to_datetime if binary["buildtime"].to_i > 0
        hash[:binary_disturl] = binary["disturl"]
        hash[:binary_supportstatus] = binary["supportstatus"]
        if binary["updateinfoid"]
          hash[:binary_updateinfo] = binary["updateinfoid"]
          hash[:binary_updateinfo_version] = binary["updateinfoversion"]
        end
        if binary["project"] and rp = Package.find_by_project_and_name(binary["project"], binary["package"])
          hash[:release_package_id] = rp.id
        end
        if binary["patchinforef"]
          begin
            pi = Patchinfo.new(Suse::Backend.get("/source/#{binary["patchinforef"]}/_patchinfo").body)
          rescue ActiveXML::Transport::NotFoundError
            # patchinfo disappeared meanwhile
          end
          # no database object on purpose, since it must also work for historic releases...
          hash[:binary_maintainer] = pi.to_hash['packager'] if pi and pi.to_hash['packager']
        end

        # new entry, also for modified binaries.
        entry = repository.binary_releases.create(hash)
        processed_item[entry.id] = true
      end

      # and mark all not processed binaries as removed
      oldlist.each do |e|
        next if processed_item[e.id]
        e.operation = "removed"
        e.obsolete_time = time
        e.save!
      end
    end
  end

end
