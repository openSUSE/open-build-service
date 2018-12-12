module Webui::Projects::StatusHelper
  def parse_status(package)
    comments_to_clear = []
    outs = []
    icon = 'ok'
    sortkey = "9-ok-#{package['name']}"

    if package['requests_from'].empty?
      package['problems'].sort.each do |problem|
        if problem == 'different_changes'
          age = distance_of_time_in_words_to_now(package['develmtime'].to_i)
          outs << link_to("Different changes in devel project (since #{age})",
                          package_rdiff_path(project: package['develproject'], package: package['develpackage'], oproject: @project.name, opackage: package['name']))
          sortkey = "5-changes-#{package['develmtime']}-#{package['name']}"
          icon = 'changes'
        elsif problem == 'different_sources'
          age = distance_of_time_in_words_to_now(package['develmtime'].to_i)
          outs << link_to("Different sources in devel project (since #{age})", package_rdiff_path(project: package['develproject'], package: package['develpackage'],
                                                                                                  oproject: @project.name, opackage: package['name']))
          sortkey = "6-changes-#{package['develmtime']}-#{package['name']}"
          icon = 'changes'
        elsif problem == 'diff_against_link'
          outs << link_to('Linked package is different', package_rdiff_path(oproject: package['lproject'], opackage: package['lpackage'],
                                                                            project: @project.name, package: package['name']))
          sortkey = "7-changes#{package['name']}"
          icon = 'changes'
        elsif problem.match?(/^error-/)
          outs << link_to(c[6..-1], package_show_path(project: package['develproject'], package: package['develpackage']))
          sortkey = "1-problem-#{package['name']}"
          icon = 'error'
        elsif problem == 'currently_declined'
          outs << link_to("Current sources were declined: request #{package['currently_declined']}",
                          request_show_path(number: package['currently_declined']))
          sortkey = "2-declines-#{package['name']}"
          icon = 'error'
        else
          outs << link_to(c, package_show_path(project: package['develproject'], package: package['develpackage']))
          sortkey = "1-changes-#{package['name']}"
          icon = 'error'
        end
      end
    end
    package['requests_to'].each do |number|
      # rubocop:disable Rails/OutputSafety
      outs.unshift("Request #{link_to(number, request_show_path(number: number))} to #{h(package['develproject'])}".html_safe)
      # rubocop:enable Rails/OutputSafety
      icon = 'changes'
      sortkey = "3-request-#{999_999 - number}-#{package['name']}"
    end
    package['requests_from'].each do |number|
      # rubocop:disable Rails/OutputSafety
      outs.unshift("Request #{link_to(number, request_show_path(number: number))} to #{h(@project.name)}".html_safe)
      # rubocop:enable Rails/OutputSafety
      icon = 'changes'
      sortkey = "2-drequest-#{999_999 - number}-#{package['name']}"
    end
    # ignore the upstream version if there are already changes pending
    if package['upstream_version'] && sortkey.nil?
      if package['upstream_url']
        outs << "New upstream version #{link_to(package['upstream_version'], package['upstream_url'])} available"
      else
        outs << "New upstream version #{package['upstream_version']} available"
      end
      sortkey = "8-outdated-#{package['name']}"
    end
    if package['firstfail']
      # rubocop:disable Rails/OutputSafety
      url = package_live_build_log_path(arch: h(package['failedarch']), repository: h(package['failedrepo']),
                                        project: h(@project.name), package: h(package['name']))
      outs.unshift("#{link_to('Fails', url)} since #{distance_of_time_in_words_to_now(package['firstfail'].to_i)}".html_safe)
      # rubocop:enable Rails/OutputSafety

      icon = 'error'
      sortkey = "1-fails-#{Time.now.to_i - package['firstfail']}-#{package['name']}"
    elsif package['failedcomment']
      comments_to_clear << package['failedcomment']
    end

    { summary: outs, sortkey: sortkey, icon_type: icon, comments_to_clear: comments_to_clear }
  end
end
