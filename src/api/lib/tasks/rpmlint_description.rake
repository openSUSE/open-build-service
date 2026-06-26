namespace :rpmlint do
  desc 'Sync RPMlint descriptions from git'
  task sync_description: :environment do
    repo = 'rpm-software-management/rpmlint'
    path = 'rpmlint/descriptions'

    client = Octokit::Client.new
    begin
      files = client.contents(repo, path: path)
    rescue Octokit::NotFound
      Rails.logger.error "Directory not found: #{path}"
      return {}
    end

    all_descriptions = {}

    files.each do |file_info|
      next unless file_info.type == 'file'

      begin
        file_content = client.contents(repo, path: file_info.path)
        file_content = Base64.decode64(file_content.content)

        all_descriptions.merge!(TomlRB.parse(file_content))
      rescue StandardError => e
        Rails.logger.warn "Failed to parse #{file_info.name}: #{e.message}"
      end
    end

    save_locally(all_descriptions)
    all_descriptions
  end

  def self.save_locally(data)
    path = Rails.root.join('tmp/rpmlint/descriptions.yaml')
    FileUtils.mkdir_p(File.dirname(path))
    File.write(path, data.to_yaml)
  end
end
