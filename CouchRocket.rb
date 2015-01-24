require 'sinatra'
# require_relative 'config/dotenv'
require_relative 'setup'
require_relative 'models'
require_all 'helpers'

#Global Variables
$delivery_fee = 3000
$return_insurance = 700
$buyer_percent = 0.80
set :domain, ENV['DOMAIN']

helpers do
  def To_Cents(dollar_amount)
    dollar_amount * 100
  end

  def To_Dollars(cents)
    cents/100
  end

  def show_params
    p params
  end

  # assign user a random password and mail it to them, asking them to change it
  def send_new_password(user)
    random_password = Array.new(10).map { (65 + rand(58)).chr }.join
    user.password = random_password
    user.save!
    #Send New Password Email
    new_password_email = {
      :from => "CouchRocket <info@#{settings.mail_domain}>",
      :to => "#{user.email}",
      :subject => "Password Reset",
      :html => erb(:'emails/new_password',
      :locals => { :user => user })
    }
    $mg_client.send_message(settings.mail_domain,new_password_email)
  end

end


#Begin Routes

get "/test" do
  erb(:'test')
end



get "/" do
  if user_signed_in? && current_user.seller_profile
    @user_items = current_user.seller_profile.items
  else
    @user_items = nil
  end

  all_items_for_sale = Item.select{|item| item.sold == false }
  @items_for_sale = all_items_for_sale.sample(5)

  erb :'home', :locals => {
    :user_items => @user_items,
    :items_for_sale => @items_for_sale,
    :user => current_user }
end

get "/FAQ" do
  erb :'faq'
end



get "/password/reset" do
  @user = User.new
  erb :'forgot_password', :locals=> {:user => @user}
end

post "/password/reset" do
@user = User.find_by_email(params[:email])
  if @user
      send_new_password(@user)
      erb :'new_password_sent'
  else
      @user = User.new
      erb :'forgot_password', :locals=> {:user => @user}
  end
end

get "/Admin" do
  if current_user.is_admin?
    @orders = Order.all
    erb :'admin', :locals => {:orders => @orders}
  else
    redirect "/"
  end
end

get "/BuyerOrderConfirmation" do
  erb(:'buyer_order_confirmation')
end

post "/Charge/:order_id" do
  show_params
  order_id = params[:order_id]
  Charge_Buyer(order_id)
  Pay_Seller(order_id)

  erb :'buyer_thanks'
end

get "/checkout" do
  show_params
  item = Item.get(params[:item_id])

  erb(:'checkout',
  :locals => { :item => item, :delivery_fee => $delivery_fee})
end


post "/checkout" do
  erb(:'checkout')
end



get "/items/new" do
  @item = Item.new
  erb :'new_item',
  :locals => { :item => @item, :user => current_user}
end

get "/items/:id" do
  show_params
  item_id = params[:id]
  @item = Item.get(item_id)
  all_items_for_sale = Item.select{|item| item.sold == false }
  @items_for_sale = all_items_for_sale.sample(5)

  erb :'sales_page', :locals => {
    :item => @item,
    :items_for_sale => @items_for_sale,
    :delivery_fee => $delivery_fee,
    :return_insurance => $return_insurance,
    :stripe_public_key => $stripe_public_key
    }
end



post "/items" do
  show_params

  if current_user.seller_profile
    @seller_profile = current_user.seller_profile
  else
    @seller_profile = SellerProfile.new({:user_id => current_user[:id]})
  end
  @seller_profile.pickup_notes = params[:pickup_notes]
  @seller_profile.save!
  @seller_profile.errors.each do |error|
    puts error
  end

  item_attrs = params[:item]
  item_attrs.merge!({ :seller_profile_id => @seller_profile.id})
  @item = Item.new(item_attrs)
  @item.original_price = To_Cents(@item.original_price)
  @item.asking_price = To_Cents(@item.asking_price)
  @item.save!
  @item.errors.each do |error|
    puts error
  end

  #Send Seller Listing Confirmation Email
  seller_listing_confirmation = {
    :from => "CouchRocket <info@#{settings.mail_domain}>",
    :to => "#{current_user.email}",
    :subject => "Thanks for Listing with CouchRocket",
    :html => erb(:'emails/seller_listing_confirmation',:locals => { :current_user => current_user, :item => @item })
  }
  $mg_client.send_message(settings.mail_domain,seller_listing_confirmation)

  redirect "/"

end


get "/BuyerAccept/:order_id" do
order_id = params[:order_id]
@order = Order.get(order_id)
@item = @order.item
erb(:'buyer_accept',:locals => {:order => @order,:item => @item})
end


post "/NotifyBuyer/:order_id" do
order_id = params[:order_id]
order = Order.get(order_id)

  begin
    message = twilio_client.account.messages.create({
      :from => "+1#{twilio_number}",
      :to => "+1#{order.buyer_phone}",
      :body => "Your delivery person from CouchRocket is here with your
      #{order.item.brand} #{order.item.type}!\n http://#{settings.domain}/BuyerAccept/#{order_id}",
      :media_url => "http://i.imgur.com/iWHg83s.png"
      })
  rescue Twilio::REST::RequestError => e
    puts e.message
    puts message.sid
  end
erb(:'notify_buyer')
end


post "/NotifySeller/:order_id" do
order_id = params[:order_id]
order = Order.get(order_id)

  begin
    message = twilio_client.account.messages.create({
      :from => "+1#{twilio_number}",
      :to => "+1#{order.seller_phone}",
      :body => "Your delivery person from CouchRocket is here to pick up
      your #{order.item.brand} #{order.item.type} and deliver to your buyer.",
      :media_url => "http://i.imgur.com/iWHg83s.png"
      })
  rescue Twilio::REST::RequestError => e
    puts e.message
    puts message.sid
  end
erb(:'notify_seller')
end

post "/orders" do
  show_params

  #Create new user (buyer)
  user_attrs = params[:user]
  @user = User.new(user_attrs)
  @user.buyer_profile = BuyerProfile.new
  @user.save!
  @user.buyer_profile.save!
  @user.errors.each do |error|
      puts error
  end

  #Fetch Item from db
  item_id = params[:item][:id]
  @item = Item.get(item_id)

  #Create new order, populate
  order_attrs = params[:order]
  @order = Order.new(order_attrs)
  @order.total_price = @item.asking_price + $delivery_fee + $return_insurance

  @order.buyer_name =@user.name
  @order.buyer_address = @user.address
  @order.buyer_phone = @user.phone

  @order.seller_name = @item.seller_profile.user.name
  @order.seller_phone = @item.seller_profile.user.phone
  @order.seller_address = @item.seller_profile.user.address
  @order.seller_share = $buyer_percent * @item.asking_price
  @order.pickup_notes = @item.seller_profile.pickup_notes


  @order.buyer_profile = @user.buyer_profile

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

  # **Stripe Customer Creation**
  # Get the credit card details submitted by the form
  token = params[:stripeToken]

  customer = Stripe::Customer.create(
  :card => token,
  :email => @user.email,
  :metadata => {
    'Name' => @user.name,
    'Phone' => @user.phone,
    'Address' => @user.address
    }
  )

  @user.buyer_profile.stripe_customer_id = customer.id
  @user.buyer_profile.save


  #Send Buyer Confirmation Email
  buyer_confirmation = {
    :from => "CouchRocket <me@#{settings.mail_domain}>",
    :to => "#{@user.email}",
    :subject => "Your #{@item.type} is Scheduled for Delivery",
    :html => erb(:'emails/buyer_confirmation',
      :locals => {:user => @user,:item => @item,:order=>@order})
  }
  $mg_client.send_message(settings.mail_domain,buyer_confirmation)

  #Look up Seller
  @seller = @item.seller_profile.user

  #Send Seller Notification Email
  seller_pickup_notification ={
    :from => "CouchRocket <me@#{settings.mail_domain}>",
    :to => "#{@seller.email}",
    :subject => "Time Sensitive: Your #{@item.type.downcase} has been sold!",
    :html => erb(:'emails/seller_pickup_notification',
    :locals => {:seller => @seller,:item=>@item,:order=>@order})
  }
  $mg_client.send_message(settings.mail_domain,seller_pickup_notification)

  redirect "/BuyerOrderConfirmation"
end

get "/register" do
  user = User.new
  erb(:'register', :locals => {:user => user})
end

post "/register" do
  show_params
  user = User.create(params[:user])

  if user.saved?
    sign_in(user)
    redirect "/items/new"
  else
    erb(:'register', :locals => {:user => user})
  end
end

get "/Return" do
  @order = Order.get(params[:order_id])
  erb(:'return',:locals =>{:order=>@order})
end


post "/Return" do
  show_params
  @order = Order.get(params[:order][:id])
  @order.approved = "Returned"
  @order.return_reason = params[:order][:return_reason]

  #Charge Buyer Shipping Only
  @buyer_profile = BuyerProfile.get(@order.buyer_profile_id)
  customer_id = @buyer_profile.stripe_customer_id

  shipping_cost = $delivery_fee + $return_insurance

  charge_create = Stripe::Charge.create(
      :amount => shipping_cost,
      :currency => "usd",
      :customer => customer_id
      )

  if charge_create.paid == true
    @order.charged = true
  else
    @order.charged = "Error"
  end
  @order.save

  #Notify Shipper to Return Item
  begin
    message = twilio_client.account.messages.create({
      :from => "+1#{twilio_number}",
      :to => "+1#{@order.shipper_phone}",
      :body => "Return #{@order.item.type} to #{@order.seller_name} at #{@order.seller_address}.\n
      Please call #{@order.seller_phone} to let them know. Thanks!",
      :media_url => "http://i.imgur.com/iWHg83s.png"
      })
  rescue Twilio::REST::RequestError => e
  puts e.message
  puts message.sid
  end

  redirect "/ReturnComplete"

end

get "/ReturnComplete" do
  erb(:'return_complete')
end

get "/ScheduleDelivery" do
  show_params
  @order = Order.get(params[:order_id])
  erb(:'schedule_delivery',
    :locals => {:order => @order})
end

post "/ScheduleDelivery" do
  show_params
  order_attrs = params[:order]
  @order = Order.get(params[:order][:id])
  @order.update(order_attrs)


  #Send Shipper Email
  shipper_email = {
    :from => "CouchRocket <me@#{settings.mail_domain}>",
    :to => "#{@order.shipper_email}",
    :subject => "#{@order.item.brand} #{@order.item.type} delivery #{@order.target_delivery_date.strftime('%A, %B %d')}",
    :html => erb(:'emails/shipper',
      :locals => {:order=>@order})
  }
  $mg_client.send_message(settings.mail_domain,shipper_email)

  @order.shipper_email_sent = true
  @order.save
  redirect "/Admin"

end


get "/SellerPaymentDetails/:order_id" do
  show_params
  order_id = params[:order_id]
  @order = Order.get(order_id)
  erb(:'seller_payment_details',
    :locals => {:stripe_public_key => stripe_public_key,
    :return_insurance => $return_insurance,
    :order => @order
    })
end

get "/sessions/new" do
  user = User.new
  erb(:'sign_in', :locals=> {:user => user})
end

post "/sessions" do
  user = User.find_by_email(params[:email])

  if user && user.valid_password?(params[:password])
    sign_in(user)
    redirect("/")
  else
    user = User.new
    erb(:'sign_in', :locals=> {:user => user})
  end
end

get "/sessions/sign_out" do
  sign_out
  redirect("/")
end

post "/SellerPaymentDetails/:order_id" do
  show_params
  order_id = params[:order_id]
  seller_attrs = params[:seller]
  @order = Order.get(order_id)
  token = params[:stripeToken]   # Get the credit card details submitted by the form

  seller_stripe_recipient_profile = Stripe::Recipient.create(
    :name => seller_attrs[:name],
    :type => "individual",
    :tax_id => seller_attrs[:ssn],
    :email => current_user.email,
    :metadata => {
    'Address' => current_user.address
    },
    :card => token
    )

  #Add to User's seller profile
  current_user.seller_profile.stripe_recipient_id = seller_stripe_recipient_profile.id
  current_user.save!

  Pay_Seller(order_id)

  erb(:'seller_thanks',:locals=>{:order=>@order})
end

get "/users/:id" do
  @user = User.get(params[:id])

  if current_user.seller_profile
    @user_items = current_user.seller_profile.items
  else
    @user_items = nil
  end

erb(:'profile',:locals=>{:user=>@user,:user_items=>@user_items})
end

get "/users/:id/edit" do
  @user = User.get(params[:id])



erb(:'edit_profile',:locals=>{
  :user=>@user,

  })
end

put "/users/:id" do
  user = User.get(params[:id])
  user_attrs = params[:user]
  user.name = user_attrs[:name]
  user.email = user_attrs[:email]
  user.phone = user_attrs[:phone]
  user.address = user_attrs[:address]
  user.save!
  redirect "/"
end

get "/users/:id/edit_password" do
  user = User.get(params[:id])
  erb(:'change_password',:locals=>{:user=>user})
end

put "/users/:id/edit_password" do
  user = User.get(params[:id])
  if user.valid_password?(params[:password])
  user.password = params[:user][:password]
  user.save!
  redirect "/"
  else
  erb(:'change_password',:locals=>{:user=>user})
  end
end






