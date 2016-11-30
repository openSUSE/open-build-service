class Product < ApplicationRecord
  belongs_to :package, foreign_key: :package_id
  has_many :product_update_repositories, dependent: :destroy
  has_many :product_media, dependent: :destroy

  include CanRenderModel

  def self.find_or_create_by_name_and_package( name, package )
    raise Product::NotFoundError.new( "Error: Package not valid." ) unless package.class == Package
    product = find_by_name_and_package name, package

    product = create( name: name, package: package ) unless product.length > 0

    product
  end

  def self.find_by_name_and_package( name, package )
    where(name: name, package: package).load
  end

  def self.all_products( project, expand = nil )
    return project.expand_all_products if expand

    joins(:package).where("packages.project_id = ? and packages.name = '_product'", project.id)
  end

  def to_axml(_opts = {})
    Rails.cache.fetch('xml_product_%d' % id) do
      # CanRenderModel
      render_xml
    end
  end

  def set_CPE(swClass, vendor, pversion = nil)
    # hack for old SLE 11 definitions
    vendor="suse" if vendor.start_with?("SUSE LINUX")
    self.cpe = "cpe:/#{swClass}:#{vendor.downcase}:#{name.downcase}"
    self.cpe += ":#{pversion}" unless pversion.blank?
  end

  def extend_id_hash(h)
    # extends an existing hash for xml rendering with our version
    if baseversion
      h[:baseversion] = baseversion
      h[:patchlevel] = patchlevel
    else
      h[:version] = version
    end
    h[:release] = release if release
    h
  end

  def update_from_xml(xml)
    transaction do
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
            next unless p['name'] == name
            self.baseversion = p['baseversion']
            self.patchlevel = p['patchlevel']
            pversion = p['version']
            pversion = p['baseversion'] if p['baseversion']
            pversion += ":sp#{p['patchlevel']}" if p['patchlevel'] && p['patchlevel'].to_i > 0
            set_CPE(swClass, p['vendor'], pversion)
            self.version = pversion
            # update update channel connections
            p.elements('register') do |r|
              _update_from_xml_register(r)
            end
          end
        end
      end
    end
  end

  private

  def _update_from_xml_register_pool(rxml)
    rxml.elements('pool') do |u|
      medium = {}
      product_media.each do |pm|
        key = "#{pm.repository.id}/#{pm.name}"
        if pm.arch_filter_id
          arch = pm.arch_filter.name
          key += "/#{arch}"
        end
        key.downcase!
        medium[key] = pm
      end
      u.elements('repository') do |repo|
        next if repo['project'].blank? # it may be just a url= reference
        poolRepo = Repository.find_by_project_and_name(repo['project'], repo['name'])
        unless poolRepo
          errors.add(:missing, "Pool repository #{repo['project']}/#{repo['name']} missing")
          next
        end
        name = repo.get('medium')
        arch = repo.get('arch')
        key = "#{poolRepo.id}/#{name}"
        key += "/#{arch}" unless arch.blank?
        key.downcase!
        unless medium[key]
          # new
          p = {product: self, repository: poolRepo, name: name}
          unless arch.blank?
            arch_filter = Architecture.find_by_name(arch)
            if arch_filter
              p[:arch_filter_id] = arch_filter.id
            else
              errors.add(:invalid, "Architecture #{arch} not valid")
            end
          end
          product_media.create(p)
        end
        medium.delete(key)
      end
      product_media.delete(medium.values)
    end
  end

  def _update_from_xml_register_update(rxml)
    rxml.elements('updates') do |u|
      update = {}
      product_update_repositories.each do |pu|
        next unless pu.repository # it may be remote or not yet exist
        key = pu.repository.id.to_s
        key += "/" + pu.arch_filter.name if pu.arch_filter_id
        update[key] = pu
      end
      u.elements('repository') do |repo|
        updateRepo = Repository.find_by_project_and_name(repo.get('project'), repo.get('name'))
        next unless updateRepo # it might be a remote repo, which will not become indexed
        arch = repo.get('arch')
        key = updateRepo.id.to_s
        p = {product: self, repository: updateRepo}
        unless arch.blank?
          key += "/#{arch}"
          arch_filter = Architecture.find_by_name(arch)
          if arch_filter
            p[:arch_filter_id] = arch_filter.id
          else
            errors.add(:invalid, "Architecture #{arch} not valid")
          end
        end
        ProductUpdateRepository.create(p) unless update[key]
        update.delete(key)
      end
      product_update_repositories.delete(update.values)
    end
  end

  def _update_from_xml_register(rxml)
    _update_from_xml_register_update(rxml)
    _update_from_xml_register_pool(rxml)
  end
end
