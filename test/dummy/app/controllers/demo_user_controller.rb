# frozen_string_literal: true

class DemoUserController < ApplicationController
  before_filter :authenticate_user!

  def members_only
    render json: {
      data: {
        message: "Welcome #{current_user.name}",
        user: current_user
      }
    }, status: 200
  end

  def members_only_remove_token
    u = User.find(current_user.id)
    u.auth_tokens = {}
    u.save!

    render json: {
      data: {
        message: "Welcome #{current_user.name}",
        user: current_user
      }
    }, status: 200
  end
end
