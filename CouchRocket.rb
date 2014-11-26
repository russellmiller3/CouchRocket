require 'sinatra'
require 'sinatra/partial'
require 'better_errors'
require 'stripe'

set :publishable_key, ENV['PUBLISHABLE_KEY']
set :secret_key, ENV['SECRET_KEY']

Stripe.api_key = settings.secret_key

require_relative 'config/dotenv'
require_relative 'models'

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
	@items = current_user.items

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
	@buyer = Buyer.new
	show_params
	erb :'partials/SalesPage', :locals => { :item => @item, :user => current_user, :buyer => @buyer }
end



post "/items" do
	show_params
	item_attrs = params[:item]
	default_buyer = Buyer.get(1)
	item_attrs.merge!({ :user => current_user, :buyer => default_buyer})
	@item = Item.new(item_attrs)
	@item.save
	@item.errors.each do |error|
		puts error
	end
  redirect "/"
end

post "/charge" do
	show_params

	buyer_attrs = params[:buyer]
	@buyer = Buyer.new(buyer_attrs)
	@buyer.stripe_token = params[:stripeToken]
	@buyer.stripe_customer_id = params[:stripeCustomerID]
	@buyer.save

	@buyer.errors.each do |error|
			puts error
	end

	item_attrs = params[:item]
	item_id = params[:item][:id]
	@item = Item.get(item_id)
	@item.update(item_attrs)
	@item.buyer_id = @buyer.id
	@item.save

	@item.errors.each do |error|
			puts error
	end



	#Stripe Payment:

	#amount in cents
	@amount = 100 * @item.asking_price
	@amount = @amount.to_i

	Stripe.api_key = "sk_test_x6GZa5DuUvqCIT7jAg20yVPH"

	# Get the credit card details submitted by the form
	token = params[:stripeToken]

	# Create a Customer
	customer = Stripe::Customer.create(
	:card => token,
	:description => @buyer.name,
	:email => @buyer.email,
	)


	# Charge the Customer instead of the card
	Stripe::Charge.create(
	:amount => @amount,
	:currency => "usd",
	:customer => customer.id,
	)

	redirect "/"

end




