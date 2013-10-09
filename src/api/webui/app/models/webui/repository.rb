class Webui::Repository < Webui::Node
  handles_xml_element 'repository'

  def archs
    @archs ||= to_hash.elements("arch")
    return @archs
  end

  def archs=(new_archs)
    new_archs.map! { |a| a.to_s }
    archs.reject { |a| new_archs.include?(a) }.each { |arch| remove_arch(arch) }
    new_archs.reject { |a| archs.include?(a) }.each { |arch| add_arch(arch) }
  end

  def add_arch(arch)
    return nil if archs.include? arch
    @archs.push arch
    e = add_element('arch')
    e.text = arch
  end

  def eemove_arch(arch)
    return nil unless archs.include? arch
    each_arch do |a|
      delete_element(a) if a.text == arch
    end
    @archs.delete arch
  end

  def paths
    @paths ||= to_hash.elements("path").map { |p| "#{p["project"]}/#{p["repository"]}" }
    return @paths
  end

  def paths=(new_paths)
    paths.clone.each { |path| remove_path(path) }
    new_paths.each { |path| add_path(path) }
  end

  def add_path(path)
    return nil if paths.include? path
    project, repository = path.split("/")
    @paths.push path
    e = add_element('path')
    e.set_attribute('repository', repository)
    e.set_attribute('project', project)
  end

  def remove_path(path)
    return nil unless paths.include? path
    project, repository = path.split("/")
    delete_element "//path[@project='#{::Builder::XChar.encode(project)}' and @repository='#{::Builder::XChar.encode(repository)}']"
    @paths.delete path
  end

  # directions are :up and :down
  def move_path(path, direction=:up)
    return nil unless (path and not paths.empty?)
    new_paths = paths.clone
    for i in 0..new_paths.length
      if new_paths[i] == path # found the path to move?
        if direction == :up and i != 0 # move up and is not the first?
          new_paths[i - 1], new_paths[i] = new_paths[i], new_paths[i - 1]
          paths=new_paths
          break
        elsif direction == :down and i != new_paths.length - 1
          new_paths[i + 1], new_paths[i] = new_paths[i], new_paths[i + 1]
          paths=new_paths
          break
        end
      end
    end
  end
end
