# cookies are too small and active record sessions cause too much load
if Rails.env.test?
  Rails.application.config.session_store ActionDispatch::Session::CookieStore
else
  Rails.application.config.session_store ActionDispatch::Session::CacheStore, :expire_after => 1.day
end
