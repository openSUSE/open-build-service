module FileService
  class Uploader
    def errors
      @errors.compact.join("\n")
    end

    def added_files
      @added_files.join(', ')
    end

    def initialize(package, files, comment)
      @commit_filelist = []
      @errors = []
      @added_files = []

      @package = package
      @files = files
      @comment = comment
    end

    def call
      fetch_existing_files

      begin
        http_upload! if @files.present?

        apply_commit_filelist
      rescue APIError, StandardError => e
        @errors << e.message
      rescue Backend::Error => e
        @errors << Xmlhash::XMLHash.new(error: e.summary)[:error]
      end
    end

    private

    def http_upload!
      @files.each do |file|
        # NOTE: the order here is important
        filename = file.original_filename
        file_content = file.open.read if file.is_a?(ActionDispatch::Http::UploadedFile)
        @added_files << filename

        @package.save_file(rev: 'repository', file: file_content, filename: filename)
        add_to_commit_filelist(filename, file_content)
      end
    end

    def fetch_existing_files
      @package.dir_hash.elements('entry').each do |e|
        @commit_filelist << e.symbolize_keys.slice(:name, :md5, :hash)
      end
    end

    def add_to_commit_filelist(name, file_content)
      index = @commit_filelist.find_index { |f| f[:name] == name }
      # Avoid duplicated files in commitfilelist, most recent file upload wins
      return (@commit_filelist << file_list_entry(name, file_content)) if index.nil?

      @commit_filelist[index][:md5] = Digest::MD5.hexdigest(file_content)
      @commit_filelist[index][:hash] = "sha256:#{Digest::SHA256.hexdigest(file_content)}"
    end

    def apply_commit_filelist
      xml = ::Builder::XmlMarkup.new
      @commit_filelist.each { |f| xml.entry(f) }

      directory = Backend::Api::Sources::Package.write_filelist(@package.project.name, @package.name,
                                                                "<directory>#{xml.target!}</directory>",
                                                                user: User.session.login, comment: @comment)
      return if directory_errors(directory)
      return if %w[_project _pattern].include?(@package.name)

      @package.sources_changed(wait_for_update: wait_for_update?)
    end

    def wait_for_update?
      special_files = %w[_aggregate _constraints _link _service _patchinfo _channel]
      contains_file = false

      @commit_filelist.each do |file|
        contains_file = true if special_files.include?(file[:name])
      end
      contains_file
    end

    def file_list_entry(name, file_content)
      { name: name, md5: Digest::MD5.hexdigest(file_content), hash: "sha256:#{Digest::SHA256.hexdigest(file_content)}" }
    end

    def directory_errors(directory)
      directory_hash = Xmlhash.parse(directory)
      return false unless directory_hash['error']

      directory_hash['entry'] = [directory_hash['entry']] if directory_hash['entry'].class != Array
      error_files = directory_hash['entry'].pluck('name')
      @errors << "#{error_files.join(', ')} #{directory_hash['error']}"
    end
  end
end
