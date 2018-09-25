# Reference: https://www.eliotsykes.com/testing-codemirror-editor
module CodeMirrorHelpers
  def fill_in_editor_field(text)
    within '.CodeMirror' do
      # Click makes CodeMirror element active:
      current_scope.click
      # Find the hidden textarea:
      field = current_scope.find('textarea', visible: false)
      # Mimic user typing the text:
      field.send_keys(text)
    end
  end
end

RSpec.configure do |config|
  config.include CodeMirrorHelpers, type: :feature
end
