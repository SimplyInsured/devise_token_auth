require_relative 'tokens_serialization'

module DeviseTokenAuth::Concerns::ActiveRecordSupport
  extend ActiveSupport::Concern

  included do
    # DINO - tokens --> auth_tokens
    # serialize :tokens, DeviseTokenAuth::Concerns::TokensSerialization
    serialize :auth_tokens, DeviseTokenAuth::Concerns::TokensSerialization
  end

  class_methods do
    # It's abstract replacement .find_by
    def dta_find_by(attrs = {})
      find_by(attrs)
    end
  end
end
