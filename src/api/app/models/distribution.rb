class Distribution < ApplicationRecord
  validates :vendor, :version, :name, :reponame, :repository, :project, presence: true

  has_and_belongs_to_many :icons, -> { distinct }, class_name: 'DistributionIcon'
  has_and_belongs_to_many :architectures, -> { distinct }, class_name: 'Architecture'

  scope :local, -> { where(remote: false) }
  scope :remote, -> { where(remote: true) }
  scope :for_project, ->(project_name) { where('project like ?', project_name + ':%') }

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

  def to_hash
    res = attributes
    res['architectures'] = architectures.map(&:name)
    res['icons'] = icons.map(&:attributes)
    res
  end

  def self.all_as_hash
    Distribution.includes(:icons, :architectures).map(&:to_hash)
  end

  def self.all_including_remotes
    list = Distribution.all_as_hash
    repositories = list.map { |d| d['reponame'] }

    Project.remote.each do |prj|
      body = Rails.cache.fetch("remote_distribution_#{prj.id}", expires_in: 1.hour) do
        Project::RemoteURL.load(prj, '/distributions.xml')
      end
      next if body.blank? # don't let broken remote instances break us

      xmlhash = Xmlhash.parse(body)
      xmlhash.elements('distribution') do |d|
        next if repositories.include?(d['reponame'])

        repositories << d['reponame']
        iconlist = []
        architecturelist = []
        d.elements('architecture') do |a|
          architecturelist << a.to_s
        end
        d.elements('icon') do |i|
          iconlist << { 'width' => i['width'], 'height' => i['height'], 'url' => i['url'] }
        end
        list << { 'vendor' => d['vendor'], 'version' => d['version'], 'name' => d['name'],
                  'project' => prj.name + ':' + d['project'], 'architectures' => architecturelist, 'icons' => iconlist,
                  'reponame' => d['reponame'], 'repository' => d['repository'], 'link' => d['link'] }
      end
    end
    list
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
