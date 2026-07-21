SimpleCov.profiles.define 'obs' do
  load_profile 'rails'

  skip '/app/indices/'
  skip '/lib/templates/'
  skip '/lib/memory_debugger.rb'
  skip '/lib/memory_dumper.rb'

  merge_timeout 3600

  group 'Components', 'app/components'
  group 'Datatables', 'app/datatables'
  group 'Instrumentations', 'app/instrumentations'
  group 'Mixins', 'app/mixins'
  group 'Policies', 'app/policies'
  group 'Queries', 'app/queries'
  group 'Services', 'app/services'
  group 'Validators', 'app/validators'
end

