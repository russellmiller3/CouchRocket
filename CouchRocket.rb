require 'sinatra'
require 'sinatra/partial'
require 'better_errors'
require 'stripe'
require 'json'
require 'pry'
require 'rest_client'

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


get "/admin" do
	@orders = Order.all

	erb :'Admin', :locals => {:orders => @orders}
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
		@seller_profile.save
	end

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

	#Send Buyer Listing Confirmation Email
	def send_buyer_listing_confirmation_message
 		RestClient.post "https://api:key-8c6ae9be29401c9e6380409be3d68318"\
  	"@api.mailgun.net/v2/sandbox43786b89d4494ff4896863476bbc7c4c.mailgun.org/messages",
	  :from => "CouchRocket <me@samples.mailgun.org>",
	  :to => "#{@current_user.email}",
	  :subject => "Thanks for Listing with CouchRocket",
	  :html => "<html>
	  <img src='http://i.imgur.com/iI7g2uKs.jpg' border='0' title='CouchRocket'></a>
	  <br><br>
	  <p>Hi #{current_user.name}. Thanks for listing your #{@item.type.downcase} with us!<br>
	  <h3>What happens next?</h3>
	  <p>We'll advertise your item, and as soon as there's a buyer we'll let you know, and send someone to pick it up.<br>
		More questions?  Check out the <a href='CouchRocket.com/FAQ'>CouchRocket FAQ</a> </p>
	  </html>"
	 end

	send_buyer_listing_confirmation_message

  redirect "/"
end

post "/orders" do
	show_params

	#Create new user (buyer)
	user_attrs = params[:user]
	@new_user = User.new(user_attrs)
	@new_user.buyer_profile = BuyerProfile.new
	@new_user.save
	@new_user.buyer_profile.save
	@new_user.errors.each do |error|
			puts error
	end

	#Fetch Item from db
	item_id = params[:item][:id]
	@item = Item.get(item_id)

	#Create new order
	order_attrs = params[:order]
	@order = Order.new(order_attrs)
	@order.total_price = @item.asking_price + 30
	@order.shipping_address = @new_user.address
	@order.buyer_profile_id =	@new_user.buyer_profile.id
	#@order.stripe_token = params[:stripeToken]
	@order.save
	@order.errors.each do |error|
			puts error
	end

	#Attach item to order, save item
	@item.order_id = @order.id
	@item.save

	@item.errors.each do |error|
			puts error
	end

	# **Stripe Payment:**
	@amount = @item.asking_price
	Stripe.api_key = "sk_test_x6GZa5DuUvqCIT7jAg20yVPH"


	# Get the credit card details submitted by the form
	token = params[:stripeToken]

	# Create a Customer
	customer = Stripe::Customer.create(
	:card => token,
	:email => @new_user.email,
	:metadata => {
		'Name' => @new_user.name,
		'Phone' => @new_user.phone,
		'Address' => @new_user.address
		}
	)

	@new_user.buyer_profile.stripe_customer_id = customer.id
	@new_user.buyer_profile.save


	#Send Buyer Confirmation Email
	def send_buyer_delivery_message
 		RestClient.post "https://api:key-8c6ae9be29401c9e6380409be3d68318"\
  	"@api.mailgun.net/v2/sandbox43786b89d4494ff4896863476bbc7c4c.mailgun.org/messages",
	  :from => "CouchRocket <me@samples.mailgun.org>",
	  :to => "#{@new_user.email}",
	  :subject => "Your #{@item.type} is Scheduled for Delivery",
	  :html => "<html>
	  <img src='http://i.imgur.com/iI7g2uKs.jpg' border='0' title='CouchRocket'></a>
	  <br><br>
	  <p>Hi #{@new_user.name}. Thanks for your order! <br>
	  <h3>What happens next?</h3>
	  <p>We'll deliver your #{@item.type.downcase} on
	  #{@order.target_delivery_date.strftime("%A, %B %d")}
	  from #{@order.target_delivery_time_start.to_i} p.m.
	  to #{@order.target_delivery_time_start.to_i+2} p.m.<br>
	 	Once you approve the item, we release it to you, charge you, and that's it!</p>
		<h3>What if I don't like the item, or there's something wrong with it?</h3>
		<p>No problem! We'll take the item back at no cost, and you won't be charged.<br>
		More questions?  Contact us at <a href='mailto:help@couchrocket.com'>CouchRocket Support</a> </p>
	  </html>"
	 end


	#Look up Seller
	@seller_profile = SellerProfile.get(@item.seller_profile_id)

	binding.pry


	@seller = User.get(@seller_profile.user_id)



	#Send Seller Notification Email
	def send_seller_pickup_message
 		RestClient.post "https://api:key-8c6ae9be29401c9e6380409be3d68318"\
  	"@api.mailgun.net/v2/sandbox43786b89d4494ff4896863476bbc7c4c.mailgun.org/messages",
	  :from => "CouchRocket <me@samples.mailgun.org>",
	  :to => "#{@seller.email}",
	  :subject => "Time Sensitive: Your #{@item.type.downcase} has been sold!",
	  :html => "<html>
	  <img src='http://i.imgur.com/iI7g2uKs.jpg' border='0' title='CouchRocket'></a>
	   <br><br>
		 Hi #{@seller.name}. Your #{@item.type.downcase} has been sold!
	   <h3>What happens next?</h3>
	   <ol>
	   <li><h4>We pick up your furniture</h4>
	    We'll come by to pick up your #{@item.type.downcase} on
	  #{@order.target_delivery_date.strftime("%A, %B %d")} between #{@order.target_delivery_time_start.to_i - 1} p.m. and
	  #{@order.target_delivery_time_start.to_i} p.m.
	  </li>
		 <li><h4>Buyer receives item and approves</h4></li>
		 <li><h4>You get paid!</h4></li>
		 </ol>
		 <h3>What if the buyer doesn't approve the item?</h3>
		 <p>We'll deliver the item back to you at no cost<br>
		 	More questions?  Contact us at <a href='mailto:help@couchrocket.com'>CouchRocket Support</a> </p>

	  	</html>"
	end


	send_buyer_delivery_message

	send_seller_pickup_message

	"<html>
	<img src='http://i.imgur.com/iI7g2uKs.jpg' border='0' title='CouchRocket'></a>
	<h1>CouchRocket</h1>
	<br><br>
	Thanks, we'll start processing your order today.<br>
	Get ready for liftoff!
	</html>"

end

post "/charge" do
	# show_params
	order_id = params[:order][:id]
	@order = Order.get(order_id)
	# p @order.total_price
	@buyer_profile = BuyerProfile.get(@order.buyer_profile_id)
	customer_id = @buyer_profile.stripe_customer_id
	# p customer_id

	charge_create = Stripe::Charge.create(
	    :amount => @order.total_price,
	    :currency => "usd",
	    :customer => customer_id
			)

  if charge_create.paid == true
		@order.charged = true
	else
		@order.charged = "Error"
	end

	@order.save

	p @order.charged

	redirect "/admin"

end






