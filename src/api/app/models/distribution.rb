class Distribution < ActiveRecord::Base
  validates_presence_of :vendor, :version, :name, :reponame, :repository, :project

  has_and_belongs_to_many :icons, -> { uniq() }, class_name: 'DistributionIcon'
  has_and_belongs_to_many :architectures, -> { uniq() }, class_name: 'Architecture'
  
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
    res = self.attributes
    res["architectures"] = []
    res["icons"] = []
    self.architectures.each do |a|
      res["architectures"] << a.name
    end
    self.icons.each do |i|
      res["icons"] << i.attributes
    end
    return res
  end
  
  def self.all_as_hash
    res = []
    Distribution.includes(:icons).includes(:architectures).each { |d| res << d.to_hash }
    return res
  end

  def self.all_including_remotes
    list = Distribution.all_as_hash
    repositories = list.map{ |d| d['reponame'] }
    
    remote_projects = Project.where("NOT ISNULL(projects.remoteurl)")
    remote_projects.each do |prj|
      body = Rails.cache.fetch("remote_distribution_#{prj.id}", expires_in: 1.hour) do
        ActiveXML.backend.load_external_url(prj.remoteurl + "/distributions.xml")
      end
      next if body.blank? # don't let broken remote instances break us
      xmlhash = Xmlhash.parse(body)
      xmlhash.elements('distribution') do |d|
        next if repositories.include?( d['reponame'] )
        repositories << d['reponame']
        iconlist = architecturelist = []
        d.elements('architecture') do |a|
          architecturelist << { "_content" => a.to_s }
        end
        d.elements('icon') do |i|
          iconlist << { "width" => i['width'], "height" => i['height'], "url" => i['url'] }
        end
        list << {"vendor" => d['vendor'], "version" => d['version'], "name" => d['name'],
          "project" => prj.name + ":" + d['project'], "architectures" => architecturelist, "icons" => iconlist,
          "reponame" => d['reponame'], "repository" => d['repository'], "link" => d['link']}
      end
    end
    return list
  end

end
