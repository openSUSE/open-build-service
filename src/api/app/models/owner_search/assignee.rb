module OwnerSearch
  class Assignee < Base
    def for(search_string)
      @match_all = limit.zero?
      @deepest = limit.negative?

      # "package_owners" could be "maintainers" or "bugowners", depending on the configuration.
      @package_owners = []

      # search in each marked project
      projects_to_look_at.each do |project|
        @rolefilter = filter(project)
        @already_checked = {}
        @rootproject = project
        @lookup_limit = limit.to_i
        @devel_disabled = devel_disabled?(project)
        find_assignees(search_string)
      end
      @package_owners
    end

    protected

    def create_owner(package)
      Owner.new(rootproject: @rootproject.name, filter: @rolefilter, project: package.project.name, package: package.name)
    end

    def extract_maintainer_project_level(owner, package)
      return owner if owner.user_or_group?

      owner.package = nil
      extract_from_container(owner, package.project, @rolefilter)
      # still not matched? Ignore it
      return owner if owner.user_or_group?

      nil
    end

    def extract_maintainer(package)
      return unless package&.project&.check_access?

      owner = create_owner(package)
      # no filter defined, so do not check for roles and just return container
      return owner if @rolefilter.empty?

      # lookup in package container
      extract_from_container(owner, package, @rolefilter)

      # eventually fallback
      extract_maintainer_project_level(owner, package)
    end

    def extract_owner(package)
      # optional check for devel package instance first
      owner = if @devel_disabled
                nil
              else
                extract_maintainer(package.resolve_devel_package)
              end
      owner || extract_maintainer(package)
    end

    def lookup_package_owner(package)
      return nil if @already_checked[package.id]

      @already_checked[package.id] = 1
      @lookup_limit -= 1

      package_owner = extract_owner(package)
      # found entry
      return package_owner if package_owner

      # no match, loop about projects below with this package container name
      package.project.expand_all_projects.each do |project|
        project_package = project.packages.find_by_name(package.name)
        next if project_package.nil? || @already_checked[project_package.id]

        @already_checked[project_package.id] = 1

        package_owner = extract_owner(project_package)
        break if package_owner && !@deepest
      end

      # found entry
      package_owner
    end

    def parse_binary_info(binary, project)
      # a binary without a package container? can only only happen
      # with manual snapshot repos...
      return false if binary['project'] != project.name || binary['package'].blank?

      package_name = binary['package']
      package_name.gsub!(/\.[^.]*$/, '') if project.maintenance_release?
      package_name = Package.striping_multibuild_suffix(package_name)
      package = project.packages.find_by_name(package_name)

      return false if package.nil? || package.patchinfo?

      package_owner = lookup_package_owner(package)

      return false unless package_owner

      # remember as deepest candidate
      if @deepest
        @deepest_match = package_owner
        return false
      end

      # add matching entry
      @package_owners << package_owner
      @lookup_limit -= 1
      true
    end

    def find_assignees(binary_name)
      projects = @rootproject.expand_all_projects

      # binary search via all projects
      data = Xmlhash.parse(Backend::Api::Search.binary(projects.map(&:name), binary_name))
      # found binary package?
      return [] if data['matches'].to_i.zero?

      @deepest_match = nil
      projects.each do |project| # project link order
        data.elements('binary').each do |binary| # no order
          next unless parse_binary_info(binary, project)
          return @package_owners if @lookup_limit < 1 && !@match_all
        end
      end

      @package_owners << @deepest_match if @deepest_match
    end
  end
end
