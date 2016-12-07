class LocalBuildResult
  include ActiveModel::Model
  attr_accessor :project, :package, :repository, :architecture, :code

  def self.find_by(opts)
    find_by_project_and_package(opts[:project], opts[:package]).select { |buildresult|
                                                                         buildresult.repository == opts[:repository] &&
                                                                         buildresult.architecture == opts[:architecture]
                                                                      }
  end

  def self.find_by_project_and_package(project, package)
    buildresults = Buildresult.find_hashed( project: project, package: package, view: 'status', multibuild: '1', locallink: '1')
    local_build_results = []
    buildresults.elements('result').each do |result|
      result.elements('status').each do |status|
        local_build_results << LocalBuildResult.new(project: result['project'],
                                                    package: status['package'],
                                                    repository: result['repository'],
                                                    architecture: result['arch'],
                                                    code: status['code']
                                                   )
      end
    end
    if local_build_results.any?{ |local_build_result| local_build_result.package.start_with?("#{package}:") }
      local_build_results.reject!{ |local_build_result| local_build_result.package == package }
    end

    local_build_results
  end
end
