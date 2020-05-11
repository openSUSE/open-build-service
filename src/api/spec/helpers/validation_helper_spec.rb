require 'rails_helper'

RSpec.describe ValidationHelper do
  describe '#valid_project_name!' do
    it 'raises an exception if a project name is invalid' do
      expect { valid_project_name!('home mschnitzer') }.to raise_error(ValidationHelper::InvalidProjectNameError)
    end

    it 'does not raise an exception on valid project names' do
      expect { valid_project_name!('home:mschnitzer') }.not_to raise_error
    end
  end
end
