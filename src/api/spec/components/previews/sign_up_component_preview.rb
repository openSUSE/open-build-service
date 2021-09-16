class SignUpComponentPreview < ViewComponent::Preview
  # Preview at http://HOST:PORT/rails/view_components/sign_up_component/sign_up
  def sign_up
    render(SignUpComponent.new(config: {}))
  end

  # Preview at http://HOST:PORT/rails/view_components/sign_up_component/create
  def create
    render(SignUpComponent.new(config: {}, create_page: true))
  end
end
