class ApplicationController < ActionController::API
  before_action :set_cors_headers

  include JWTSessions::RailsAuthorization
  include ApiResponseFormatter #custom response formatter for api
  
  rescue_from JWTSessions::Errors::Unauthorized, with: :not_authorized
  rescue_from ActiveRecord::RecordNotFound, with: :not_found
  rescue_from ActionController::ParameterMissing, with: :bad_request

  def test_auth
    render_success({ status: 'ok' })  # Updated to use standardized response
  end

  private
  
  def current_user
    @current_user || (User.find(payload['user_id'])) #comes from the JWT sessions (line 2)
  end
  
  def not_authorized
    render_error(
      'AUTHENTICATION_ERROR', 
      'Invalid or expired token', 
      status: :unauthorized
    )
  end

  def not_found
    render_error(
      'RESOURCE_NOT_FOUND',
      'The requested resource was not found',
      status: :not_found
    )
  end

  def bad_request
    render_error(
      'BAD_REQUEST',
      'Invalid request parameters',
      status: :bad_request
    )
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