class RpmlintLogExtractor
  attr_reader :project, :package, :repository, :architecture, :log_content

  def initialize(attributes = {})
    @project = attributes[:project]
    @package = attributes[:package]
    @repository = attributes[:repository]
    @architecture = attributes[:architecture]

    @log_content = ''
  end

  def call
    # Retrieve the content of the 'rpmlint.log' file
    Backend::Api::BuildResults::Binaries.rpmlint_log(project, package, repository, architecture)
  rescue Backend::NotFoundError => e
    # TODO: Remove this `unless` condition once request_show_redesign is rolled out
    return unless Flipper.enabled?(:request_show_redesign, User.session)

    # Case of removed project, package, repository or architecture:
    return unless e.summary.include?('rpmlint.log: No such file or directory')

    # Case of debian builds:
    return unless rpms_exist?

    retrieve_rpmlint_log_from_log
  end

  private

  def rpms_exist?
    binaries = Backend::Api::BuildResults::Binaries.files(project, repository, architecture, package)
    binaries.match?(/<binary filename="\S+\.rpm"/)
  end

  def retrieve_rpmlint_log_from_log
    log_content = Backend::Api::BuildResults::Binaries.file(project, repository, architecture, package, '_log')

    # The OBS rpmlint mark is defined here: https://github.com/openSUSE/obs-build/blob/44e43abe9da522c1c6685742aecc55be158da55b/build-recipe-spec#L331
    mark1 = '\[\s*\d+s\]\s\n'
    mark2 = '\[\s*\d+s\]\sRPMLINT report:\n'
    mark3 = '\[\s*\d+s\]\s===============\n'

    log_content.sub!(/.+#{mark1}#{mark2}#{mark3}/m, '')

    # The OBS rpmlint mark was not found
    return if log_content.blank?

    # Remove lines after last line of rpmlint log
    mark1 = '\[\s*\d+s\] +\d+ packages and \d+ specfiles checked; [^\n]+\n'
    log_content = log_content.sub(/(.+#{mark1}).+/m, '\1')

    # Remove column of brackets and times
    log_content.gsub(/^\[\s*\d+s\] /, '')
  end
end
