module FileService
  class Uploader
    attr_reader :errors, :added_files

    def initialize(package, files, empty_files, file_urls, comment)
      @commit_filelist = []
      @errors = []
      @added_files = []

      @package = package
      @files = files
      @empty_files = empty_files
      @file_urls = file_urls
      @comment = comment
    end

    def call
      fetch_existing_files

      begin
        empty_files if @empty_files.present?
        http_upload if @files.present?
        remote_files if @file_urls.present?

        apply_commit_filelist
      rescue APIError => e
        @errors << e.message
      rescue Backend::Error => e
        @errors << Xmlhash::XMLHash.new(error: e.summary)[:error]
      rescue StandardError => e
        @errors << e.message
      end

      @errors << 'No file or URI given' if @added_files.empty?
    end

    private

    def http_upload
      @files.each do |file|
        # NOTE: the order here is important
        filename = file.original_filename
        file_content = file.open.read if file.is_a?(ActionDispatch::Http::UploadedFile)
        @added_files << filename

        @package.save_file(rev: 'repository', file: file_content, filename: filename)
        add_to_commit_filelist(filename, file_content)
      end
    end

    def remote_files
      service = @package.services
      service_file = ''

      Hash[*@file_urls].try(:each) do |name, url|
        @added_files << name
        service_file = service.add_download_url(url, name).to_xml
      end

      service.save ? add_to_commit_filelist('_service', service_file) : @errors << 'Failed to add file from URL'
    end

    def empty_files
      @empty_files.each do |filename|
        @added_files << filename
        @package.save_file(rev: 'repository', filename: filename)

        add_to_commit_filelist(filename, '')
      end
    end

    def fetch_existing_files
      @package.dir_hash.elements('entry').each do |e|
        @commit_filelist << { name: e['name'], md5: e['md5'], hash: e['hash'] }
      end
    end

    def add_to_commit_filelist(name, file_content)
      unless @commit_filelist.empty?
        # Avoid duplicated files in commitfilelist, most recent file upload wins
        overwritten = false

        @commit_filelist.each do |f|
          if f[:name] == name
            f[:md5], f[:hash] = Digest::MD5.hexdigest(file_content),
                                'sha256:' + Digest::SHA256.hexdigest(file_content)
            overwritten = true
            break
          end
        end

        return if overwritten
      end

      @commit_filelist << file_list_entry(name, file_content)
    end


    def apply_commit_filelist
      xml = ::Builder::XmlMarkup.new
      @commit_filelist.each do |f|
        xml.entry('name' => f[:name], 'md5' => f[:md5], 'hash' => f[:hash])
      end

      Backend::Api::Sources::Package.write_filelist(@package.project.name, @package.name,
                                                    "<directory>#{xml.target!}</directory>",
                                                    user: User.session!.login, comment: @comment)

      return if ['_project', '_pattern'].include?(@package.name)

      @package.sources_changed(wait_for_update: wait_for_update?)
    end

    def wait_for_update?
      special_files = ['_aggregate', '_constraints', '_link', '_service', '_patchinfo', '_channel']
      contains_file = false

      @commit_filelist.each do |file|
        contains_file = true if special_files.include?(file[:name])
      end
      contains_file
    end

    def file_list_entry(name, file_content)
      { name: name, md5: Digest::MD5.hexdigest(file_content), hash: 'sha256:' + Digest::SHA256.hexdigest(file_content) }
    end
  end
end
