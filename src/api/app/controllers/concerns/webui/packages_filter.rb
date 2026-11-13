module Webui::PackagesFilter
  extend ActiveSupport::Concern

  TEXT_SEARCH_MAX_RESULTS = 10_000

  def filter_packages
    @packages = filter_packages_by_search_text(@packages, @filter_search_text)
  end

  def set_selected_filter
    @selected_filter = { search: @filter_search_text }
  end

  def filter_packages_by_search_text(packages, filter_search_text)
    return packages if filter_search_text.blank?

    search_for_ids_options = { per_page: TEXT_SEARCH_MAX_RESULTS, star: true }

    if Package.search_count(filter_search_text, star: true) > TEXT_SEARCH_MAX_RESULTS
      # De-group before counting: filter_labels may have added a GROUP BY, and calling
      # .count on a grouped relation returns a Hash ({id => count}), which raises when
      # compared against an Integer. unscope(:group) keeps this an Integer count.
      if packages.unscope(:group).limit(TEXT_SEARCH_MAX_RESULTS + 1).count > TEXT_SEARCH_MAX_RESULTS
        flash.now[:error] = 'Your text search pattern matches too many results. Please, try again with a more restrictive search pattern.'
        packages = Package.none

        return
      end

      search_for_ids_options[:with] = { package_id: packages.pluck(:id) }
    end

    packages.where(id: Package.search_for_ids(filter_search_text, search_for_ids_options))
  rescue ThinkingSphinx::ParseError, ThinkingSphinx::SyntaxError
    flash.now[:error] = "Check your search expression. Use the <a href='https://sphx.org/docs/sphinx3.html#cheat-sheet' target='blank'>syntax guide</a> for help."
    Package.none
  end

  def set_filter_search_text
    @filter_search_text = params[:search]
  end

  def set_ordered_packages
    @packages = @packages.order(name: :asc)
  end

  def paginate_packages
    @packages = @packages.page(params[:page]).per(params[:page_size])
  end
end
