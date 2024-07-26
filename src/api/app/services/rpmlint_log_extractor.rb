class RpmlintLogExtractor
  attr_reader :project, :package, :repository, :architecture, :log_content

  def initialize(attributes = {})
    @project = attributes[:project]
    @package = attributes[:package]
    @repository = attributes[:repository]
    @architecture = attributes[:architecture]

    @log_content = ''

    # metrics
    @rpmlint_log_file_found = true
    @parse_internal_log_file = false
    @mark_found = true
  end

  def call
    time_start = Time.now.to_f
    content = begin
      # Retrieve the content of the 'rpmlint.log' file
      Backend::Api::BuildResults::Binaries.rpmlint_log(project, package, repository, architecture)&.scrub
    rescue Backend::NotFoundError => e
      @rpmlint_log_file_found = false

      # Condition: Flipper.enabled?(...   : TODO: Remove this `unless` condition once request_show_redesign is rolled out
      # Condition: e.summary.include?(... : Case of removed project, package, repository or architecture
      retrieve_rpmlint_log_from_log if Flipper.enabled?(:request_show_redesign, User.session) && e.summary.include?('rpmlint.log: No such file or directory')
    end

    time_delta = (Time.now.to_f - time_start).round(3)
    metrics = "rpmlint_log_file_found=#{@rpmlint_log_file_found},parse_internal_log_file=#{@parse_internal_log_file},mark_found=#{@mark_found}"
    RabbitmqBus.send_to_bus('metrics', "rpmlint_log_extractor,#{metrics} value=#{time_delta}")

    content
  end

  private

  # Note: This method is used when rpmlint.log file is not available in the backend.
  # It parses the '_log' file and search for rpmlint logs in it
  def retrieve_rpmlint_log_from_log
    @parse_internal_log_file = true

    log_content = Backend::Api::BuildResults::Binaries.file(project, repository, architecture, package, '_log')
    # Remove invalid byte sequences
    log_content.scrub!

    # The OBS rpmlint mark is defined here: https://github.com/openSUSE/obs-build/blob/44e43abe9da522c1c6685742aecc55be158da55b/build-recipe-spec#L331
    mark1 = '\[\s*\d+s\]\s\n'
    mark2 = '\[\s*\d+s\]\sRPMLINT report:\n'
    mark3 = '\[\s*\d+s\]\s===============\n'

    log_content = log_content.sub!(/.+#{mark1}#{mark2}#{mark3}/m, '')

    # Return if the OBS rpmlint mark was not found
    return unless (@mark_found = log_content.present?)

    # Remove lines after last line of rpmlint log
    mark1 = '\[\s*\d+s\] +\d+ packages and \d+ specfiles checked; [^\n]+\n'
    log_content = log_content.sub(/(.+#{mark1}).+/m, '\1')

    # Remove column of brackets and times
    log_content.gsub(/^\[\s*\d+s\] /, '')
  end
end
