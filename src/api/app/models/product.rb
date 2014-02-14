class Product < ActiveRecord::Base

  belongs_to :package, foreign_key: :package_id
  has_many :product_update_repositories, dependent: :destroy

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
              r.elements('updates') do |u|
                u.elements('repository') do |repo|
                  updateRepo = Repository.find_by_project_and_repo_name(repo.get('project'), repo.get('name'))
                  ProductUpdateRepository.create(product: self, repository: updateRepo)
                end
              end
            end
          end
        end
      end
    end
  end
end
