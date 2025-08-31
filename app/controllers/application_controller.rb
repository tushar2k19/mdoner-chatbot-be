class ApplicationController < ActionController::API
  before_action :set_cors_headers

  include JWTSessions::RailsAuthorization
  rescue_from JWTSessions::Errors::Unauthorized, with: :not_authorized

  def test_auth
    render json: { status: 'ok' }
  end

  private
  def current_user
    @current_user || (User.find(payload['user_id']))#comes from the JWT sessions (line 2)
  end
  def not_authorized
    render json: { error: "Not authorized" }, status: :unauthorized
  end
  def set_cors_headers
    # Temporarily allow all origins for testing
    response.headers['Access-Control-Allow-Origin'] = request.headers['Origin']
    response.headers['Access-Control-Allow-Credentials'] = 'true'
    response.headers['Access-Control-Allow-Methods'] = 'GET, POST, PUT, PATCH, DELETE, OPTIONS'
    response.headers['Access-Control-Allow-Headers'] = 'Origin, Content-Type, Accept, Authorization, X-CSRF-Token'
    response.headers['Access-Control-Expose-Headers'] = 'access-token, expiry, token-type, Authorization'
  end

  def authenticate_user!
    current_user
  end
end
