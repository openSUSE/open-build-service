module ModelsAuthentication
  def login(user)
    User.session = user
  end

  def logout
    User.session = nil
  end
end

RSpec.configure do |c|
  c.include ModelsAuthentication, type: :model
  c.include ModelsAuthentication, type: :mailer
end
