module UserService
  class Involved
    MAX_ITEMS_PER_PAGE = 25
    KLASS_FILTER = %w[involved_projects involved_packages].freeze

    attr_reader :user, :filters

    def initialize(user:, filters:, page:)
      @user = user
      @filters = prepare_filters(filters: filters)
      @page = page
    end

    def involved_pkg_and_prj_paginated
      Kaminari.paginate_array(involved_packages_and_projects).page(@page).per(MAX_ITEMS_PER_PAGE)
    end

    def sort_involved_items(involved_items)
      involved_items.sort_by do |involved_item|
        if involved_item.is_a?(Package)
          "#{involved_item.project} / #{involved_item}".downcase
        else
          involved_item.name.downcase
        end
      end
    end

    def involved_packages_and_projects
      involved_items = []
      roles = roles_to_filter

      involved_items.concat(involved_items_as_owner) if filter_by_owner?

      if filter_by_role?
        involved_items.concat(pkg_or_prj_filtered_by_roles(user: @user, klass: Project, roles: roles)) if consider_involved_projects?
        involved_items.concat(pkg_or_prj_filtered_by_roles(user: @user, klass: Package, roles: roles).includes(:project)) if consider_involved_packages?
      else
        involved_items.concat(pkg_or_prj_unfiltered(user: @user, klass: Package).includes(:project)) if consider_involved_packages?
        involved_items.concat(pkg_or_prj_unfiltered(user: @user, klass: Project)) if consider_involved_projects?
      end
      sort_involved_items(involved_items.uniq)
    end

    def owner_root_project_exists?
      Project.joins(:attribs).exists?(attribs: { attrib_type: AttribType.find_by_name!('OBS:OwnerRootProject') })
    end

    def involved_items_as_owner
      @involved_items_as_owner ||= []

      return @involved_items_as_owner if @involved_items_as_owner.present? || !owner_root_project_exists?

      @involved_items_as_owner.concat(
        OwnerSearch::Owned.new.for(@user)
                          .filter_map { |owner| owned_item(user: owner, search_text: @filters['search_text']) }
      )
    end

    private

    def prepare_filters(filters:)
      filters['search_text'] = filters['search_text']&.strip
      filters
    end

    def filter_by_role?
      roles_to_filter.present?
    end

    def filter_by_owner?
      @filters['role_owner'].present?
    end

    def consider_involved_projects?
      return true if @filters['involved_projects'].present?

      !klass_filter_present?
    end

    def consider_involved_packages?
      return true if @filters['involved_packages'].present?

      !klass_filter_present?
    end

    def klass_filter_present?
      @filters.keys.intersect?(KLASS_FILTER)
    end

    def search_text_present?
      @filters['search_text'].present?
    end

    def owned_item(user:, search_text: '')
      item = owned_project_or_package(user: user)

      return if item.nil?
      return if search_text.present? && !item.to_s.match?(Regexp.escape(search_text))

      item
    end

    def owned_project_or_package(user:)
      if user.package.present?
        user.package if consider_involved_packages?
      elsif consider_involved_projects?
        user.project
      end
    end

    def roles_to_filter
      @filters.keys.select { |key| key != 'role_owner' && key =~ /^role_/ }.map { |key| Role.hashed[key.delete_prefix('role_')] }
    end

    def pkg_or_prj_unfiltered(user:, klass:)
      return klass.none if filter_by_owner?

      results = klass.related_to_user(user.id).or(klass.related_to_group(user.group_ids))
      results = filter_by_search_text(klass: results) if search_text_present?

      results
    end

    def pkg_or_prj_filtered_by_roles(user:, klass:, roles:)
      results = klass.related_to_user(user.id).where(relationships: { role_id: roles }).or(
        klass.related_to_group(user.group_ids).where(relationships: { role_id: roles })
      )
      results = filter_by_search_text(klass: results) if search_text_present?

      results
    end

    def filter_by_search_text(klass:)
      klass.where('LOWER(name) LIKE ?', "%#{@filters['search_text'].downcase}%")
    end
  end
end
