# frozen_string_literal: true

module DeviseTokenAuth::Concerns::UserOmniauthCallbacks
  extend ActiveSupport::Concern

  included do
    # DINO - Commented a bunch of stuff out here for DM support.  We're not using Omniauth, so shouldn't matter either way once we're on AR
    #validates_with_method :ensure_uid
    # validates :email, presence: true,if: :email_provider?
    # validates :email, :devise_token_auth_email => true, allow_nil: true, allow_blank: true, if: :email_provider?
    # validates_presence_of :uid, unless: :email_provider?

    # only validate unique emails among email registration users
    # validates :email, uniqueness: { case_sensitive: false, scope: :provider }, on: :create, if: :email_provider?

    # keep uid in sync with email
    #before :save, :sync_uid
    # before :create, :sync_uid
  end

  def ensure_uid
    if provider != 'email' && !!uid
      [false, 'No uid provided']
    else
      [true]
    end
  end

  protected

  def email_provider?
    true # provider == 'email'
  end

  def sync_uid
    if false && devise_modules.include?(:confirmable) && !@bypass_confirmation_postpone # Disable confirmable
      return if postpone_email_change?
    end
    self.uid = email if email_provider?
  end
end
