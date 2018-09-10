class StatusProjectController < ApplicationController
  before_action :initialize_caches, only: [:show]

  def show
    dbproj = Project.get_by_name(params[:project])
    @packages = ProjectStatus::Calculator.new(dbproj).calc_status
    find_relationships_for_packages
  end

  private

  def initialize_caches
    @package_hash = {}
  end

  def role_from_cache(role_id)
    @rolecache ||= Hash.new do |h, rid|
      h[rid] = Role.find(rid).title
    end
    @rolecache[role_id]
  end

  def user_from_cache(user_id)
    @usercache ||= Hash.new do |h, uid|
      h[uid] = User.find(uid).login
    end
    @usercache[user_id]
  end

  def group_from_cache(group_id)
    @groupcache ||= Hash.new do |h, gid|
      h[gid] = Group.find(gid).title
    end
    @groupcache[group_id]
  end

  def package_hash(packages)
    return @package_hash unless @package_hash.empty?
    packages.each_value do |pkg|
      @package_hash[pkg.package_id] = pkg
      @package_hash[pkg.develpack.package_id] = pkg.develpack if pkg.develpack
    end
    @package_hash
  end

  def relationships_for_package(keys)
    Relationship.with_packages(keys).pluck(:package_id, :user_id, :group_id, :role_id)
  end

  def add_person(user_id, role_id, package_id)
    package_hash(@packages)[package_id].add_person(user_from_cache(user_id),
                                                   role_from_cache(role_id))
  end

  def add_group(group_id, role_id, package_id)
    package_hash(@packages)[package_id].add_group(group_from_cache(group_id),
                                                  role_from_cache(role_id))
  end

  def find_relationships_for_packages
    relationships_for_package(package_hash(@packages).keys).each do |package_id, user_id, group_id, role_id|
      if user_id
        add_person(user_id, role_id, package_id)
      else
        add_group(group_id, role_id, package_id)
      end
    end
  end
end
