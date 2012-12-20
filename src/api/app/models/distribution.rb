class Distribution < ActiveRecord::Base
  validates_presence_of :vendor, :version, :name, :reponame, :repository, :project
  attr_accessible :vendor, :version, :name, :project, :reponame, :repository, :link

  has_and_belongs_to_many :icons, :class_name => 'DistributionIcon'
  
  def self.parse(xmlhash)
    Distribution.transaction do
      Distribution.destroy_all
      DistributionIcon.delete_all
      xmlhash.elements('distribution') do |d|
	db = Distribution.create(vendor: d['vendor'], version: d['version'], name: d['name'], project: d['project'], 
				 reponame: d['reponame'], repository: d['repository'], link: d['link']) 
	d.elements('icon') do |i|
          dbi = DistributionIcon.find_or_create_by_url(width: i['width'], height: i['height'], url: i['url'])
	  db.icons << dbi
	end
      end
    end
  end

  def self.load_distributions_from_remote(prj)
    # TODO: add proxy handling
    url = URI.parse( prj.remoteurl + "/distributions.xml" )
    http = Net::HTTP.new(url.host, url.port)
    http.use_ssl = (url.scheme == 'https')
    response = http.get(url.path)
    # TODO: fix response != 200
    return response.body
  end

  def to_hash
    res = self.attributes
    res["icons"] = []
    self.icons.each do |i|
      res["icons"] << i.attributes
    end
    return res
  end
  
  def self.all_as_hash
    res = []
    Distribution.all.each { |d| res << d.to_hash }
    return res
  end

  def self.all_including_remotes
    local = Distribution.all_as_hash

    remote = Rails.cache.fetch("remote_distribution_list", expires_in: 1.day) do
      list = []
      remote_projects = Project.where("NOT ISNULL(projects.remoteurl)")
      remote_projects.each do |prj|
        xmlhash = Xmlhash.parse(self.load_distributions_from_remote(prj))
        logger.debug "AIR #{prj} #{xmlhash}"
        xmlhash.elements('distribution') do |d|
          iconlist = []
          d.elements('icon') do |i|
            iconlist << { "width" => i['width'], "height" => i['height'], "url" => i['url'] }
          end
          list << {"vendor" => d['vendor'], "version" => d['version'], "name" => d['name'],
                   "project" => prj.name + ":" + d['project'], "icons" => iconlist,
                   "reponame" => d['reponame'], "repository" => d['repository'], "link" => d['link']}
        end
      end
      list
    end

    return local + remote
  end

end
