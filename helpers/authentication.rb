helpers do
	def current_user
		return nil unless session.key?(:user_id)
		@current_user ||= User.get(session[:user_id])
	end

	def user_signed_in?
		!current_user.nil?
	end

	def sign_in(user)
		session[:user_id] = user.id
		@current_user = user
	end

	def sign_out
		@current_user = nil
		session.delete(:user_id)
	end

end
