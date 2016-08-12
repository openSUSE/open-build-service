class Buildresult < ActiveXML::Node
  # rubocop:disable Style/AlignHash
  AVAIL_STATUS_VALUES = {
    succeeded:    0,
    failed:       1,
    unresolvable: 2,
    broken:       3,
    blocked:      4,
    dispatching:  5,
    scheduled:    6,
    building:     7,
    finished:     8,
    signing:      9,
    disabled:    10,
    excluded:    11,
    locked:      12,
    deleting:    13,
    unknown:     14
  }
  # rubocop:enable Style/AlignHash

  STATUS_DESCRIPTION = {
      succeeded:    "Package has built successfully and can be used to build further packages.",
      failed:       "The package does not build successfully. No packages have been created. Packages " +
                    "that depend on this package will be built using any previously created packages, if they exist.",
      unresolvable: "The build can not begin, because required packages are either missing or not explicitly defined.",
      broken:       "The sources either contain no build description (e.g. specfile), automatic source processing failed or a " +
                    "merge conflict does exist.",
      blocked:      "This package waits for other packages to be built. These can be in the same or other projects.",
      scheduled:    "A package has been marked for building, but the build has not started yet.",
      dispatching:  "A package is being copied to a build host. This is an intermediate state before building.",
      building:     "The package is currently being built.",
      signing:      "The package has been built successfully and is assigned to get signed.",
      finished:     "The package has been built and signed, but has not yet been picked up by the scheduler. This is an " +
                    "intermediate state prior to 'succeeded' or 'failed'.",
      disabled:     "The package has been disabled from building in project or package metadata.",
      excluded:     "The package build has been disabled in package build description (for example in the .spec file) or " +
                    "does not provide a matching build description for the target.",
      unknown:      "The scheduler has not yet evaluated this package. Should be a short intermediate state for new packages."
  }.with_indifferent_access

  def self.status_description(status)
    STATUS_DESCRIPTION[status] || "status explanation not found"
  end

  def self.avail_status_values
    AVAIL_STATUS_VALUES.keys.map(&:to_s)
  end

  def self.code2index(code)
    index = AVAIL_STATUS_VALUES[code.to_sym]
    if index
      index
    else
      raise ArgumentError, "code '#{code}' unknown #{AVAIL_STATUS_VALUES.inspect}"
    end
  end

  def self.index2code(index)
    AVAIL_STATUS_VALUES.key(index)
  end
end
