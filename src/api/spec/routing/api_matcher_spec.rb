require 'rails_helper'

RSpec.describe 'APIMatcher' do
  it 'routes xml format request to API controllers' do
    expect(get('/distributions.xml')).to route_to(controller: 'distributions', action: 'index', format: 'xml')
  end

  it 'distributions in html format should not be routable' do
    expect(get('/distributions')).not_to be_routable
  end

  it 'routes public routes correctly' do
    expect(get('/public/source/project/package/file')).to route_to(
      controller: 'public',
      action:     'source_file',
      project:    'project',
      package:    'package',
      filename:   'file'
    )
    expect(get('/public/build/project/repository/arch/package/file')).to route_to(
      controller: 'public',
      action:     'build',
      project:    'project',
      repository: 'repository',
      arch:       'arch',
      package:    'package',
      file:       'file'
    )
  end
end
