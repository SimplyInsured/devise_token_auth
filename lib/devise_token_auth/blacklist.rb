# don't serialize tokens
Devise::Models::Authenticatable::BLACKLIST_FOR_SERIALIZATION << :auth_tokens
