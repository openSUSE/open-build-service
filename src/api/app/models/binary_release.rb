class BinaryRelease < ActiveRecord::Base

  belongs_to :repository

  # optional
  has_one :build_container, :class_name => "Package", foreign_key: :id
  belongs_to :release_container, :class_name => "Package", foreign_key: "release_container_id"

  before_create :set_release_time

  def set_release_time
    # created_at, but readable in database
    self.binary_releasetime = Time.now
  end

  class << self
    def find_by_repo_and_name( repo, name )
      self.where(:repository => repo, :binary_name => name)
    end
  end

  def create_attributes
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
    builder.binary(create_attributes) do |b|
      r={}
      if self.release_container
        r[:project] = self.release_container.project.name
        r[:package] = self.release_container.name
      end
      r[:time] = self.binary_releasetime if self.binary_releasetime
      b.release(r) if r.length > 0

      r={}
      if self.build_container
        r[:project] = self.build_container.project.name
        r[:package] = self.build_container.name
      end
      r[:time] = self.binary_buildtime if self.binary_buildtime
      b.build(r) if r.length > 0

      b.delete(:time => self.binary_deletetime) if self.binary_deletetime

      b.supportstatus self.binary_supportstatus if self.binary_supportstatus
      b.maintainer self.binary_maintainer if self.binary_maintainer
      b.disturl self.binary_disturl if self.binary_disturl

    end
    builder.to_xml
  end

  def to_axml_id
    builder = Nokogiri::XML::Builder.new
    builder.binary(create_attributes)
    builder.to_xml
  end

  def to_axml
    Rails.cache.fetch('xml_binary_release_%d' % id) do
      render_xml
    end
  end

end
