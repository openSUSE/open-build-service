Rails.autoloaders.each do |autoloader|
  autoloader.inflector = Zeitwerk::Inflector.new
  autoloader.inflector.inflect(
    'api_matcher' => 'APIMatcher',
    'cve_parser' => 'CVEParser',
    'meta_xml_validator' => 'MetaXMLValidator',
    'obs_quality_categories_finder' => 'OBSQualityCategoriesFinder',
    'opensuse_upstream_tarball_url_finder' => 'OpenSUSEUpstreamTarballURLFinder',
    'opensuse_upstream_version_finder' => 'OpenSUSEUpstreamVersionFinder',
    'remote_url' => 'RemoteURL',
    'rss_channel' => 'RSSChannel',
    'url_generator' => 'URLGenerator',
    'scm_status_reporter' => 'SCMStatusReporter',
    'scm_exception_handler' => 'SCMExceptionHandler',
    'yaml_to_workflows_service' => 'YAMLToWorkflowsService',
    'yaml_downloader' => 'YAMLDownloader'
  )
end
