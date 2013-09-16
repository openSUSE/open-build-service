class Buildresult < ActiveXML::Node

  @@avail_status_values =
    ['succeeded', 'failed', 'unresolvable', 'broken',
      'blocked', 'dispatching', 'scheduled', 'building', 'finished', 'signing',
      'disabled', 'excluded', 'locked', 'deleting', 'unknown']
  @@status_hash = nil

  def self.avail_status_values
    return @@avail_status_values
  end

  def code2index(code)
    unless @@status_hash
      index = 0
      @@status_hash = Hash.new
      @@avail_status_values.each do |s|
        @@status_hash[s] = index
        index += 1
      end
    end
    raise ArgumentError, "code '#{code}' unknown #{@@status_hash.inspect}" unless @@status_hash[code]
    return @@status_hash[code]
  end

  def index2code(index)
    return @@avail_status_values[index]
  end

  def to_a
    myarray = Array.new
    to_hash.elements("result") do |result|
      result["summary"].elements("statuscount") do |sc|
        myarray << [result["repository"], result["arch"], code2index(sc["code"]), sc["count"]]
      end
    end
    myarray.sort!
    repos = Array.new
    orepo = nil
    oarch = nil
    archs = nil
    counts = nil
    myarray.each do |repo, arch, code, count|
      if orepo != repo
        archs << [oarch, counts] if oarch
	oarch = nil
        repos << [orepo, archs] if orepo
	archs = Array.new
      end
      orepo = repo
      if oarch != arch
         archs << [oarch, counts] if oarch
         counts = Array.new
      end
      oarch = arch
      counts << [index2code(code), count]
    end
    archs << [oarch, counts] if oarch
    repos << [orepo, archs] if orepo
    repos ||= Array.new
  end

end
