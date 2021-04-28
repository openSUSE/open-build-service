module Workflows
  class YAMLDownloadService
    MAX_FILE_SIZE = 1024 * 1024 # 1MB

    attr_reader :errors

    def initialize(url:)
      @url = url
      @errors = []
    end

    def call
      download_yaml_file
    end

    private

    def download_yaml_file
      Down.download(@url, max_size: MAX_FILE_SIZE)
    rescue Down::Error => e
      @errors << e.message
    end
  end
end
