module PackageVersionLabeler
  extend ActiveSupport::Concern

  VERSION_STATE_LABEL_TEMPLATES = {
    'Outdated' => '#e01b24',
    'Up to date' => '#33d17a',
    'No Upstream' => '#f6d32d'
  }.freeze

  def update_package_version_labels(package_ids:)
    packages = Package.where(id: package_ids).includes(:project, :labels, :latest_local_version, :latest_upstream_version)

    packages.group_by(&:project).each do |project, project_packages|
      templates = ensure_label_templates_for(project)

      project_packages.each do |package|
        set_label_on_package(package, templates)
      end
    end
  end

  private

  def ensure_label_templates_for(project)
    existing = project.label_templates.where(name: VERSION_STATE_LABEL_TEMPLATES.keys).index_by(&:name)

    missing_names = VERSION_STATE_LABEL_TEMPLATES.keys - existing.keys

    missing_names.each do |name|
      existing[name] = project.label_templates.create!(name: name, color: VERSION_STATE_LABEL_TEMPLATES[name])
    end

    existing
  end

  def set_label_on_package(package, templates)
    # 1. Determine which label we need
    target_name = determine_label_name(package)
    target_template = templates[target_name]

    # 2. Identify version labels currently on the package
    version_template_ids = templates.values.map(&:id)
    current_labels = package.labels.select { |l| version_template_ids.include?(l.label_template_id) }

    # 3. Only update if the current label is wrong
    return if current_labels.one? && current_labels.first.label_template_id == target_template.id

    package.labels.where(label_template_id: version_template_ids).delete_all
    package.labels.create!(label_template: target_template)
  end

  def determine_label_name(package)
    local = package.latest_local_version&.version
    upstream = package.latest_upstream_version&.version

    return 'No Upstream' if upstream.blank?

    local == upstream ? 'Up to date' : 'Outdated'
  end
end
