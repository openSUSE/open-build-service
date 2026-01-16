# Rails form helpers wrap controls with a .field_with_errors class that prevents the validation styles from bootstrap to work.
# This snippet replaces the wrapping with that class with an injection of .is-invalid class, which is bootstrap compatible.
ActionView::Base.field_error_proc = proc do |html|
  frag = Nokogiri::HTML5::DocumentFragment.parse(html)
  element = frag.children[0]

  if element.attributes['class']
    element.attributes['class'].value = [element.attributes['class'], 'is-invalid'].join(' ')
  else
    element['class'] = 'is-invalid'
  end

  frag.to_html.html_safe # rubocop:disable Rails/OutputSafety -- The input is code from our views, so it's safe to disable this
end
