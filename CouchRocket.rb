require 'sinatra'
require 'sinatra/partial'
require 'better_errors'
require 'stripe'

require_relative 'config/dotenv'
require_relative 'models'

set :publishable_key, ENV['PUBLISHABLE_KEY']
set :secret_key, ENV['SECRET_KEY']

Stripe.api_key = settings.secret_key

set :partial_template_engine, :erb

configure :development do
  use BetterErrors::Middleware
  BetterErrors.application_root = File.expand_path('..', __FILE__)
end

helpers do
  def current_user
    @current_user ||= User.last
  end
end

def show_params
	p params
end

get "/" do
	@items = current_user.seller_profile.items

	erb :'Home', :locals => { :items => @items, :user => current_user }

end

get "/items" do
	@item = Item.new
	erb :'partials/AddItem', :locals => { :item => @item, :user => current_user }
end

get "/items/:id" do
	show_params
	item_id = params[:id]
	@item = Item.get(item_id)
	show_params
	erb :'partials/SalesPage', :locals => { :item => @item }
end

post "/items" do
	show_params

	if current_user.seller_profile
		@seller_profile = current_user.seller_profile
	else
		@seller_profile = SellerProfile.new({:user_id => current_user[:id]})
	end

	@seller_profile.save
	@seller_profile.errors.each do |error|
		puts error
	end

	item_attrs = params[:item]
	item_attrs.merge!({ :seller_profile_id => @seller_profile.id})



	@item = Item.new(item_attrs)
	@item.original_price = 100 * @item.original_price
	@item.asking_price = 100 * @item.asking_price
	@item.save
	@item.errors.each do |error|
		puts error
	end

  redirect "/"
end

post "/charge" do
	show_params

	#Create new user (buyer)
	user_attrs = params[:user]
	@new_user = User.new(user_attrs)
	@new_user.buyer_profile = BuyerProfile.new

	#Attach item to buyer
	item_id = params[:item][:id]
	@item = Item.get(item_id)
	@item.buyer_profile_id = @new_user.buyer_profile.id

	@item.errors.each do |error|
			puts error
	end

	#Create new order
	@order = OrderDetails.new
	@order.delivery_notes = params[:order][:delivery_notes]
	@order.stripe_token = params[:stripeToken]
	@order.stripe_customer_id = params[:stripeCustomerID]
	@order.save

	#Attach item to order
	@item.order_details_id = @order.id
	@item.save

	# **Stripe Payment:**
	@amount = @item.asking_price
	Stripe.api_key = "sk_test_x6GZa5DuUvqCIT7jAg20yVPH"

	# Get the credit card details submitted by the form
	token = params[:stripeToken]

	# Create a Customer
	customer = Stripe::Customer.create(
	:card => token,
	:description => @new_user.name,
	:email => @new_user.email,
	)

	# Charge the Customer instead of the card
	Stripe::Charge.create(
	:amount => @amount,
	:currency => "usd",
	:customer => customer.id,
	)

	redirect "/"

end




