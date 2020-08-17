# frozen_string_literal: true

module DeviseTokenAuth::Concerns::SetUserByToken
  extend ActiveSupport::Concern
  include DeviseTokenAuth::Concerns::ResourceFinder

  included do
    before_filter :set_request_start
    after_filter :update_auth_header
  end

  protected

  # keep track of request duration
  def set_request_start
    @request_started_at = Time.zone.now
    @used_auth_by_token = true

    # initialize instance variables
    @token ||= DeviseTokenAuth::TokenFactory.new
    @resource ||= nil
    @is_batch_request ||= nil
  end

  # user auth
  def set_user_by_token(mapping = nil)
    # DINO - Commenting out mapping parameter here because we're still using the old devise session controller
    # for which this will break if we pass in any params (resource_class in old devise expects 0 params).
    # Note that we've hard-coded resource_class to use :account, which will always be the value of mapping here.

    # determine target authentication class
    rc = resource_class#(mapping)

    # no default user defined
    return unless rc

    # gets the headers names, which was set in the initialize file
    uid_name = DeviseTokenAuth.headers_names.with_indifferent_access[:'uid']
    access_token_name = DeviseTokenAuth.headers_names.with_indifferent_access[:'access-token']
    client_name = DeviseTokenAuth.headers_names.with_indifferent_access[:'client']

    # parse header for values necessary for authentication
    uid              = request.headers[uid_name] || params[uid_name]
    @token           = DeviseTokenAuth::TokenFactory.new unless @token
    @token.token     ||= request.headers[access_token_name] || params[access_token_name]
    @token.client ||= request.headers[client_name] || params[client_name]

    # client isn't required, set to 'default' if absent
    @token.client ||= 'default'

    # check for an existing user, authenticated via warden/devise, if enabled
    if DeviseTokenAuth.enable_standard_devise_support
      devise_warden_user = warden.user(rc.to_s.underscore.to_sym)
      if devise_warden_user && devise_warden_user.auth_tokens[@token.client].nil?
        @used_auth_by_token = false
        @resource = devise_warden_user
        # REVIEW: The following line _should_ be safe to remove;
        #  the generated token does not get used anywhere.
        # @resource.create_new_auth_token
      end
    end


    # user has already been found and authenticated
    return @resource if @resource && @resource.is_a?(rc)

    # ensure we clear the client
    unless @token.present?
      @token.client = nil
      return
    end

    # mitigate timing attacks by finding by uid instead of auth token

    # DINO - guid instead of uid for our model
    user = uid && rc.dta_find_by(guid: uid)
    scope = rc.to_s.underscore.to_sym

    if user && user.valid_token?(@token.token, @token.client)
      # sign_in with bypass: true will be deprecated in the next version of Devise
      if respond_to?(:bypass_sign_in) && DeviseTokenAuth.bypass_sign_in
        bypass_sign_in(user, scope: scope)
      else
        sign_in(scope, user, store: false, event: :fetch, bypass: DeviseTokenAuth.bypass_sign_in)
      end
      return @resource = user
    else

      # zero all values previously set values
      @token.client = nil
      return @resource = nil
    end
  end

  def update_auth_header
    # cannot save object if model has invalid params
    return unless @resource && @token.client

    # Generate new client with existing authentication
    @token.client = nil unless @used_auth_by_token

    if @used_auth_by_token && !DeviseTokenAuth.change_headers_on_each_request
      # should not append auth header if @resource related token was
      # cleared by sign out in the meantime
      return if @resource.reload.auth_tokens[@token.client].nil?

      auth_header = @resource.build_auth_header(@token.token, @token.client)

      # update the response header
      response.headers.merge!(auth_header)

    else
      unless @resource.reload.valid?
        # @resource = @resource.class.get(@resource.to_param) # errors remain after reload
        @resource = @resource.class.find(@resource.to_param) # errors remain after reload


        # if we left the model in a bad state, something is wrong in our app
        unless @resource.valid?
          raise DeviseTokenAuth::Errors::InvalidModel, "Cannot set auth token in invalid model. Errors: #{@resource.errors.full_messages}"
        end
      end
      refresh_headers
    end
  end

  # DINO - added to help support redirect with auth params
  def build_auth_params
    return {} unless @resource && @token && @token.token

    @resource.build_auth_header(@token.token, @token.client)
  end

  private

  def refresh_headers
    # Lock the user record during any auth_header updates to ensure
    # we don't have write contention from multiple threads

    @resource.with_lock do
      # should not append auth header if @resource related token was
      # cleared by sign out in the meantime
      return if @used_auth_by_token && @resource.auth_tokens[@token.client].nil?

      # update the response header
      response.headers.merge!(auth_header_from_batch_request)
    end # end lock
  end

  def is_batch_request?(user, client)
    !params[:unbatch] &&
      user.auth_tokens[client] &&
      user.auth_tokens[client]['updated_at'] &&
      user.auth_tokens[client]['updated_at'].to_time > @request_started_at - DeviseTokenAuth.batch_request_buffer_throttle
  end

  def auth_header_from_batch_request
    # determine batch request status after request processing, in case
    # another processes has updated it during that processing
    @is_batch_request = is_batch_request?(@resource, @token.client)

    auth_header = {}
    # extend expiration of batch buffer to account for the duration of
    # this request
    if @is_batch_request
      auth_header = @resource.extend_batch_buffer(@token.token, @token.client)

      # Do not return token for batch requests to avoid invalidated
      # auth_tokens returned to the client in case of race conditions.
      # Use a blank string for the header to still be present and
      # being passed in a XHR response in case of
      # 304 Not Modified responses.
      auth_header[DeviseTokenAuth.headers_names[:"access-token"]] = ' '
      auth_header[DeviseTokenAuth.headers_names[:"expiry"]] = ' '
    else
      # update Authorization response header with new token
      auth_header = @resource.create_new_auth_token(@token.client)
    end
    auth_header
  end
end
