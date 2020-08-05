# frozen_string_literal: true

require 'test_helper'

class DeviseTokenAuth::BlacklistTest < ActiveSupport::TestCase
  describe Devise::Models::Authenticatable::BLACKLIST_FOR_SERIALIZATION do
    test 'should include :auth_tokens' do
      assert Devise::Models::Authenticatable::BLACKLIST_FOR_SERIALIZATION.include?(:auth_tokens)
    end
  end
end
