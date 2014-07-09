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
    products = ProductMedium.where( :repository => repository ).map{ |i| i.product if i.product }
    products += ProductUpdateRepository.where( :repository => repository ).map{ |i| i.product if i.product }
    products.uniq
  end

  def render_attributes
    p = { :project    => repository.project.name,
          :repository => repository.name,
        }
    [ :binary_name, :binary_epoch, :binary_version, :binary_release, :binary_arch ].each do |key|
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
      b.maintainer self.binary_maintainer if self.binary_maintainer
      b.disturl self.binary_disturl if self.binary_disturl

      b.products do |p|
         self.used_in_products.each do |product|
           p.product( :project => product.package.project.name, :name => product.name )
         end
      end
    end
    builder.to_xml
  end

  def to_axml_id
    builder = Nokogiri::XML::Builder.new
    builder.binary(render_attributes)
    builder.to_xml
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

end
