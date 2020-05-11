module BranchPackage::DryRun
  class Report
    def initialize(packages, target_project)
      @packages = packages
      @target_project = target_project
    end

    def to_xml
      @packages.sort! { |x, y| x[:target_package] <=> y[:target_package] }
      builder = Builder::XmlMarkup.new(indent: 2)
      builder.collection do
        @packages.each do |p|
          builder.package(generate_build_for_package(p)) do
            builder.devel(project: p[:copy_from_devel].project.name, package: p[:copy_from_devel].name) if p[:copy_from_devel]
            builder.target(project: @target_project, package: p[:target_package])
          end
        end
      end
    end

    private

    def generate_build_for_package(p)
      if p[:package].is_a?(Package)
        { project: p[:link_target_project].name, package: p[:package].name }
      else
        { project: p[:link_target_project], package: p[:package] }
      end
    end
  end
end
