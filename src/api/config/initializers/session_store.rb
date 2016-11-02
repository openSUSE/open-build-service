# cookies are too small and active record sessions cause too much load
Rails.application.config.session_store ActionDispatch::Session::CacheStore, expire_after: 1.day
