class Product < ApplicationRecord
  belongs_to :package
  has_many :product_update_repositories, dependent: :destroy
  has_many :product_media, dependent: :destroy

  include CanRenderModel

  def self.find_or_create_by_name_and_package(name, package)
    raise Product::NotFoundError, 'Error: Package not valid.' unless package.instance_of?(Package)

    product = find_by_name_and_package(name, package)

    product = create(name: name, package: package) if product.empty?

    product
  end

  def self.find_by_name_and_package(name, package)
    where(name: name, package: package).load
  end

  def self.all_products(project, expand = nil)
    return project.expand_all_products if expand == '1'

    joins(package: :package_kinds).where(packages: { project: project }, package_kinds: { kind: 'product' })
  end

  def to_axml(_opts = {})
    Rails.cache.fetch("xml_product_#{id}") do
      # CanRenderModel
      render_xml
    end
  end

  def set_cpe(sw_class, vendor, pversion = nil)
    # HACK: for old SLE 11 definitions
    vendor = 'suse' if vendor.start_with?('SUSE LINUX')
    self.cpe = "cpe:/#{sw_class}:#{vendor.downcase}:#{name.downcase}"
    self.cpe += ":#{pversion}" if pversion.present?
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
        sw_class = 'o'
        pd.elements('mediasets') do |ms|
          ms.elements('media') do |m|
            # product depends on others, so it is no standalone operating system
            sw_class = 'a' unless m.elements('productdependency').empty?
          end
        end
        pd.elements('products') do |ps|
          ps.elements('product') do |p|
            next unless p['name'] == name

            self.baseversion = p['baseversion']
            self.patchlevel = p['patchlevel']
            pversion = p['version']
            pversion = p['baseversion'] if p['baseversion']
            pversion += ":sp#{p['patchlevel']}" if p['patchlevel'] && p['patchlevel'].to_i.positive?
            set_cpe(sw_class, p['vendor'], pversion)
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

        pool_repo = Repository.find_by_project_and_name(repo['project'], repo['name'])
        unless pool_repo
          errors.add(:missing, "Pool repository #{repo['project']}/#{repo['name']} missing")
          next
        end
        name = repo.get('medium')
        arch = repo.get('arch')
        key = "#{pool_repo.id}/#{name}"
        key += "/#{arch}" if arch.present?
        key.downcase!
        unless medium[key]
          # new
          p = { product: self, repository: pool_repo, name: name }
          if arch.present?
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
        key += "/#{pu.arch_filter.name}" if pu.arch_filter_id
        update[key] = pu
      end
      u.elements('repository') do |repo|
        project = repo.get('project')
        name = repo.get('name')
        next if project.blank? || name.blank? # might be already defined via external url

        update_repo = Repository.find_by_project_and_name(project, name)
        next unless update_repo # it might be a remote repo, which will not become indexed

        key = update_repo.id.to_s
        p = { product: self, repository: update_repo }
        arch = repo.get('arch')
        if arch.present?
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

# == Schema Information
#
# Table name: products
#
#  id          :integer          not null, primary key
#  baseversion :string(255)
#  cpe         :string(255)
#  name        :string(255)      not null, indexed => [package_id]
#  patchlevel  :string(255)
#  release     :string(255)
#  version     :string(255)
#  package_id  :integer          not null, indexed => [name], indexed
#
# Indexes
#
#  index_products_on_name_and_package_id  (name,package_id) UNIQUE
#  package_id                             (package_id)
#
# Foreign Keys
#
#  products_ibfk_1  (package_id => packages.id)
#
