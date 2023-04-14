SimpleCov.start 'rails' do
  add_filter '/app/indices/'
  add_filter '/lib/templates/'
  add_filter '/lib/memory_debugger.rb'
  add_filter '/lib/memory_dumper.rb'
  merge_timeout 3600
  add_group 'Components', 'app/components'
  add_group 'Datatables', 'app/datatables'
  add_group 'Instrumentations', 'app/instrumentations'
  add_group 'Mixins', 'app/mixins'
  add_group 'Policies', 'app/policies'
  add_group 'Queries', 'app/queries'
  add_group 'Services', 'app/services'
  add_group 'Validators', 'app/validators'
end
