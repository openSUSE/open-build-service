class Product < ActiveRecord::Base

  belongs_to :package, foreign_key: :package_id

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
    self.cpe = "cpe:/#{swClass}:#{vendor}:#{self.name}"
    self.cpe += ":#{version}" if version
  end

end
