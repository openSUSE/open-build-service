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
