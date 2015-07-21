class Buildresult < ActiveXML::Node

  AVAIL_STATUS_VALUES = [
    "succeeded",
    "failed",
    "unresolvable",
    "broken",
    "blocked",
    "dispatching",
    "scheduled",
    "building",
    "finished",
    "signing",
    "disabled",
    "excluded",
    "locked",
    "deleting",
    "unknown"
  ]

  @@status_hash = nil

  def self.avail_status_values
    AVAIL_STATUS_VALUES
  end

  def self.code2index(code)
    unless @@status_hash
      @@status_hash = Hash.new
      AVAIL_STATUS_VALUES.each_with_index do |s,index|
        @@status_hash[s] = index
      end
    end
    raise ArgumentError, "code '#{code}' unknown #{@@status_hash.inspect}" unless @@status_hash[code]
    @@status_hash[code]
  end

  def self.index2code(index)
    AVAIL_STATUS_VALUES[index]
  end

end
