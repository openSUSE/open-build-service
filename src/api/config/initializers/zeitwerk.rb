Rails.autoloaders.each do |autoloader|
  autoloader.inflector = Zeitwerk::Inflector.new
  autoloader.inflector.inflect(
    'api_matcher' => 'APIMatcher',
    'cve_parser' => 'CVEParser',
    'gitea_api' => 'GiteaAPI',
    'meta_xml_validator' => 'MetaXMLValidator',
    'obs_quality_categories_finder' => 'OBSQualityCategoriesFinder',
    'opensuse_upstream_tarball_url_finder' => 'OpenSUSEUpstreamTarballURLFinder',
    'opensuse_upstream_version_finder' => 'OpenSUSEUpstreamVersionFinder',
    'remote_url' => 'RemoteURL',
    'report_to_scm_job' => 'ReportToSCMJob',
    'rss_channel' => 'RSSChannel',
    'scm_status_report' => 'SCMStatusReport',
    'scm_status_reporter' => 'SCMStatusReporter',
    'scm_exception_handler' => 'SCMExceptionHandler',
    'scm_exception_message' => 'SCMExceptionMessage',
    'scm_extractor' => 'SCMExtractor',
    'scm_webhook' => 'SCMWebhook',
    'scm_webhook_event_validator' => 'SCMWebhookEventValidator',
    'scm_webhook_instrumentation' => 'SCMWebhookInstrumentation',
    'yaml_to_workflows_service' => 'YAMLToWorkflowsService',
    'yaml_downloader' => 'YAMLDownloader'
  )
end
