require_relative 'tokens_serialization'

module DeviseTokenAuth::Concerns::ActiveRecordSupport
  # extend ActiveSupport::Concern

  def self.included(base)
    base.extend ClassMethods
    base.class_eval do
      serialize :auth_tokens, DeviseTokenAuth::Concerns::TokensSerialization
    end
  end

  module ClassMethods
    # It's abstract replacement .find_by
    def dta_find_by(attrs = {})
      find_by(attrs)
    end
  end

  # DINO - this syntax isn't supported yet
  # included do
  #   serialize :auth_tokens, DeviseTokenAuth::Concerns::TokensSerialization
  # end
  #
  # class_methods do
  #   # It's abstract replacement .find_by
  #   def dta_find_by(attrs = {})
  #     find_by(attrs)
  #   end
  # end
end
