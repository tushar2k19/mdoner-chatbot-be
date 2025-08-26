class SigninController < ApplicationController
  # POST /signin
  def create
    user = User.find_by(email: params[:email])
    if user&.authenticate(params[:password])
      payload = { user_id: user.id }
      session = JWTSessions::Session.new(payload: payload, refresh_by_access_allowed: true)
      tokens = session.login

      render json: {
        success: true,
        access: tokens[:access],
        csrf: tokens[:csrf],
        user: {
          id: user.id,
          first_name: user.first_name,
          last_name: user.last_name,
          email: user.email,
          role: user.role
        }
      }
    else
      render json: { error: 'Invalid email or password' }, status: :unauthorized
    end
  end

  # DELETE /signout
  def destroy
    begin
      session = JWTSessions::Session.new(payload: payload)
      session.flush_by_access_payload
      render json: { message: 'Logged out successfully' }, status: :ok
    rescue JWTSessions::Errors::Unauthorized
      render json: { error: 'Not authorized' }, status: :unauthorized
    end
  end
end



