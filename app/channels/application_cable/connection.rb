module ApplicationCable
  class Connection < ActionCable::Connection::Base
    identified_by :current_user

    def connect
      self.current_user = find_verified_user
    end

    private

    #  ** implement the below logic later for better security **

    # def find_verified_user
    #   token = request.params[:token]
    #   decoded_token = JWT.decode(token, Rails.application.credentials.jwt_secret)[0]
    #   User.find(decoded_token['user_id'])
    # rescue
    #   reject_unauthorized_connection
    # end

    def find_verified_user
      cookies_data = JSON.parse(decodeURIComponent(cookies['user_info']))
      User.find_by(email: cookies_data['email'])
    rescue
      reject_unauthorized_connection
    end
  end
end
