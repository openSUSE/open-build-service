class Product < ActiveRecord::Base

  belongs_to :package, foreign_key: :package_id
  has_many :product_update_repositories, dependent: :destroy
  has_many :product_media, dependent: :destroy

  def self.find_or_create_by_name_and_package( name, package )
    raise Product::NotFoundError.new( "Error: Package not valid." ) unless package.class == Package
    product = self.find_by_name_and_package name, package

    product = self.create( :name => name, :package => package ) unless product.length > 0

    return product
  end

  def self.find_by_name_and_package( name, package )
    return self.where(name: name, package: package).load
  end

  def set_CPE(swClass, vendor, version=nil)
    # hack for old SLE 11 definitions
    vendor="suse" if vendor.start_with?("SUSE LINUX")
    self.cpe = "cpe:/#{swClass}:#{vendor.downcase}:#{self.name.downcase}"
    self.cpe += ":#{version}" if version
  end

  def update_from_xml(xml)
    self.transaction do
      xml.elements('productdefinition') do |pd|
        # we are either an operating system or an application for CPE
        swClass = "o"
        pd.elements("mediasets") do |ms|
          ms.elements("media") do |m|
            # product depends on others, so it is no standalone operating system
            swClass = "a" if m.elements("productdependency").length > 0
          end
        end
        pd.elements('products') do |ps|
          ps.elements('product') do |p|
            next unless p['name'] == self.name
            unless version = p['version']
              version = "#{p['baseversion']}.#{p['patchlevel']}"
            end
            self.set_CPE(swClass, p['vendor'], version)
            # update update channel connections
            p.elements('register') do |r|
              r.elements('pool') do |u|
                medium = {}
                self.product_media.each do |pm|
                  medium[pm.repository.id] = pm
                end
                u.elements('repository') do |repo|
                  next if repo['project'].blank? # it may be just a url= reference
                  poolRepo = Repository.find_by_project_and_repo_name(repo['project'], repo['name'])
                  raise UnknownRepository.new "Pool repository #{repo['project']}/#{repo['name']} does not exist" unless poolRepo
                  if medium[poolRepo.id]
                    if medium[poolRepo.id].medium != repo.get('media')
                      # update
                      medium[poolRepo.id].medium = repo.get('media')
                      medium[poolRepo.id].save
                    end
                    medium.delete(poolRepo.id)
                  else
                    # new
                    self.product_media.create(product: self, repository: poolRepo, medium: repo.get('media'))
                  end
                end
                self.product_media.delete(medium.values)
              end
              r.elements('updates') do |u|
                update = {}
                self.product_update_repositories.each do |pu|
                  update[pu.repository.id] = pu
                end
                u.elements('repository') do |repo|
                  updateRepo = Repository.find_by_project_and_repo_name(repo.get('project'), repo.get('name'))
                  raise UnknownRepository.new "Update repository #{repo['project']}/#{repo['name']} does not exist" unless updateRepo
                  unless update[updateRepo]
                    ProductUpdateRepository.create(product: self, repository: updateRepo)
                    update.delete(updateRepo.id)
                  end
                end
                self.product_update_repositories.delete(update.values)
              end
            end
          end
        end
      end
    end
  end
end
