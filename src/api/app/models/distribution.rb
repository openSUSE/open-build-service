class Distribution < ApplicationRecord
  validates :vendor, :version, :name, :reponame, :repository, :project, presence: true

  has_and_belongs_to_many :icons, -> { distinct }, class_name: 'DistributionIcon'
  has_and_belongs_to_many :architectures, -> { distinct }, class_name: 'Architecture'

  def self.parse(xmlhash)
    Distribution.transaction do
      Distribution.destroy_all
      DistributionIcon.delete_all
      xmlhash.elements('distribution') do |d|
        db = Distribution.create(vendor: d['vendor'], version: d['version'], name: d['name'], project: d['project'],
                                 reponame: d['reponame'], repository: d['repository'], link: d['link'])
        d.elements('architecture') do |a|
          dba = Architecture.find_by_name!(a.to_s)
          db.architectures << dba
        end
        d.elements('icon') do |i|
          dbi = DistributionIcon.find_or_create_by(width: i['width'], height: i['height'], url: i['url'])
          db.icons << dbi
        end
      end
    end
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
        begin
          ActiveXML::Transport.load_external_url(prj.remoteurl + '/distributions.xml')
        rescue OpenSSL::SSL::SSLError
          # skip, but do not die if remote instance have invalid SSL
          Rails.logger.error "Remote instance #{prj.remoteurl} has no valid SSL certificate"
          next
        end
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
#  vendor     :string(255)      not null
#  version    :string(255)      not null
#  name       :string(255)      not null
#  project    :string(255)      not null
#  reponame   :string(255)      not null
#  repository :string(255)      not null
#  link       :string(255)
#
