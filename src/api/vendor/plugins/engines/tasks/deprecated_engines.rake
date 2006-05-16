# Old-style engines rake tasks.
# NOTE: THESE ARE DEPRICATED! PLEASE USE THE NEW STYLE!

task :engine_info => "engines:info"
task :engine_migrate => "db:migrate:engines"
task :enginedoc => "doc:engines"
task :load_plugin_fixtures => "db:fixtures:engines:load"