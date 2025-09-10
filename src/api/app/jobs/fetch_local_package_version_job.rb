class FetchLocalPackageVersionJob < ApplicationJob
  queue_as :default

  def perform(project_name, package_name: nil)
    results = Backend::Api::BuildResults::Status.result_swiss_knife(project_name, { view: :versrel, locallink: 1, multibuild: 1,
                                                                                    package: package_name,
                                                                                    code: %w[succeeded failed unresolvable blocked
                                                                                             dispatching scheduled building finished
                                                                                             signing] }.compact)

    Nokogiri::XML(results).xpath('//status[@versrel]').group_by { |s| s['package'] }.each do |package, statuses|
      next unless (package = Package.find_by_project_and_name(project_name, package))
      succeeded = statuses.find { |s| s['code'] == 'succeeded' }
      version = if succeeded.nil?
                  statuses.map { |s| parse_version(s['versrel']) }.tally.max_by { |_, c| c }.first
                else
                  parse_version(succeeded['versrel'])
                end

      PackageVersionLocal.find_or_create_by(version: version, package: package)
    end
  end

  def parse_version(versrel)
    versrel.gsub(/-[0-9]+\Z/, '')
  end
end
