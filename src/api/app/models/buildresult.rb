class Buildresult
  attr_accessor :status

  AVAIL_STATUS_VALUES = {
    succeeded: 0,
    failed: 1,
    unresolvable: 2,
    broken: 3,
    blocked: 4,
    dispatching: 5,
    scheduled: 6,
    building: 7,
    finished: 8,
    signing: 9,
    disabled: 10,
    excluded: 11,
    locked: 12,
    deleting: 13,
    unknown: 14
  }.freeze

  STATUS_DESCRIPTION = {
    succeeded: 'Package has built successfully and can be used to build further packages.',
    failed: 'The package does not build successfully. No packages have been created. Packages ' \
            'that depend on this package will be built using any previously created packages, if they exist.',
    unresolvable: 'The build can not begin, because required packages are either missing or not explicitly defined.',
    broken: 'The sources either contain no build description (e.g. specfile), automatic source processing failed or a ' \
            'merge conflict does exist.',
    blocked: 'This package waits for other packages to be built. These can be in the same or other projects.',
    scheduled: 'A package has been marked for building, but the build has not started yet.',
    dispatching: 'A package is being copied to a build host. This is an intermediate state before building.',
    building: 'The package is currently being built.',
    signing: 'The package has been built successfully and is assigned to get signed.',
    finished: 'The package has been built and signed, but has not yet been picked up by the scheduler. This is an ' \
              "intermediate state prior to 'succeeded' or 'failed'.",
    disabled: 'The package has been disabled from building in project or package metadata. ' \
              'Packages that depend on this package will be built using any previously created packages, if they still exist.',
    excluded: 'The package build has been disabled in package build description (for example in the .spec file) or ' \
              'does not provide a matching build description for the target.',
    locked: 'The package is frozen',
    unknown: 'The scheduler has not yet evaluated this package. Should be a short intermediate state for new packages.'
  }.with_indifferent_access.freeze

  STATUS_CATEGORIES = %w[succeeded failed processing blocked disabled].freeze

  STATUS_CATEGORIES_MAP = {
    succeeded: STATUS_CATEGORIES[0],
    failed: STATUS_CATEGORIES[1],
    unresolvable: STATUS_CATEGORIES[1],
    broken: STATUS_CATEGORIES[1],
    blocked: STATUS_CATEGORIES[3],
    scheduled: STATUS_CATEGORIES[2],
    dispatching: STATUS_CATEGORIES[2],
    building: STATUS_CATEGORIES[2],
    signing: STATUS_CATEGORIES[2],
    finished: STATUS_CATEGORIES[2],
    disabled: STATUS_CATEGORIES[4],
    excluded: STATUS_CATEGORIES[4],
    locked: STATUS_CATEGORIES[3],
    deleting: STATUS_CATEGORIES[2],
    unknown: STATUS_CATEGORIES[3]
  }.with_indifferent_access.freeze

  StatusCount = Struct.new(:code, :count)

  def initialize(status)
    @status = status
  end

  def self.find_hashed(opts = {})
    begin
      xml = Backend::Api::BuildResults::Status.result_swiss_knife(opts.delete(:project), opts)
    rescue  Backend::NotFoundError
      xml = nil
    end
    return Xmlhash::XMLHash.new({}) unless xml

    Xmlhash.parse(xml)
  end

  def self.status_description(status)
    STATUS_DESCRIPTION[status] || 'status explanation not found'
  end

  def self.avail_status_values
    AVAIL_STATUS_VALUES.keys.map(&:to_s)
  end

  def self.default_status_filter_values
    avail_status_values - %w[disabled excluded unknown]
  end

  def self.final_status?(status)
    status.in?(%w[succeeded failed unresolvable broken disabled excluded])
  end

  def self.summary(project_name)
    results = find_hashed(project: project_name, view: 'summary')
    local_build_results = {}
    results.elements('result').sort_by { |a| a['repository'] }.each do |result|
      state =
        if result.key?('dirty')
          "outdated_#{result['state']}"
        else
          result['state']
        end

      build = LocalBuildResult.new(
        repository: result['repository'],
        architecture: result['arch'],
        code: result['code'],
        details: result['details'],
        state: state
      )

      build.summary = []
      result['summary'].elements('statuscount').each do |count|
        build.summary << StatusCount.new(count['code'], count['count'])
      end

      build.summary.sort! { |a, b| code2index(a.code) <=> code2index(b.code) }
      local_build_results[result['repository']] ||= []
      local_build_results[result['repository']] << build
    end

    local_build_results
  end

  def self.code2index(code)
    index = AVAIL_STATUS_VALUES[code.to_sym]
    return index if index

    raise ArgumentError, "code '#{code}' unknown #{AVAIL_STATUS_VALUES.inspect}"
  end

  def successful_final_status?
    status.in?(['succeeded'])
  end

  def unsuccessful_final_status?
    status.in?(%w[failed unresolvable broken])
  end

  def in_progress_status?
    status.in?(%w[blocked dispatching scheduled building finished signing locked deleting unknown])
  end

  def refused_status?
    status.in?(%w[disabled excluded])
  end
end
