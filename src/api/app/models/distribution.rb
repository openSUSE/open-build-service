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
				 reponame: d['reponame'], repository: d['repository'],link: d['link']) 
	d.elements('icon') do |i|
          dbi = DistributionIcon.find_or_create_by_url(width: i['width'], height: i['height'], url: i['url'])
	  db.icons << dbi
	end
      end
    end
  end
end
