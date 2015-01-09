helpers do

  def Charge_Buyer(order_id)
    @order = Order.get(order_id)
    @order.approved = :true

    @buyer_profile = BuyerProfile.get(@order.buyer_profile_id)
    customer_id = @buyer_profile.stripe_customer_id

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
  end

  def Pay_Seller(order_id)
    @order = Order.get(order_id)

    if
      #Seller has a Stripe recipient profile, Pay Seller
      @order.item.seller_profile.stripe_recipient_id
      pay_seller_transfer = Stripe::Transfer.create(
      :amount =>   @order.seller_share,
      :currency => "usd",
      :recipient => "#{@order.item.seller_profile.stripe_recipient_id}",
      :description => "Payment for CouchRocket sale"
      )
      @order.seller_paid = true
      @order.save

      #Email Seller Confirmation of Payment
      seller_payment_confirmation = {
      :from => "CouchRocket <info@#{settings.mail_domain}>",
      :to => "#{@order.item.seller_profile.user.email}",
      :subject => "Payment Confirmation for #{@order.item.type.downcase}",
      :html => erb(:'emails/seller_payment_confirmation',:locals => { :order => @order})
      }
      $mg_client.send_message(settings.mail_domain,seller_payment_confirmation)

    else
      #Email Seller to Register with Stripe
      seller_payment_details_request = {
      :from => "CouchRocket <info@#{settings.mail_domain}>",
      :to => "#{@order.item.seller_profile.user.email}",
      :subject => "Your #{@order.item.type.downcase} sold! Now let's get you paid!",
      :html => erb(:'emails/seller_payment_details_request',:locals => { :order => @order})
      }
      $mg_client.send_message(settings.mail_domain,seller_payment_details_request)
    end
  end



  def Stripe_Error_Handling(code)
    begin
      code
    rescue Stripe::CardError => e
      # Since it's a decline, Stripe::CardError will be caught
    rescue Stripe::InvalidRequestError => e
      # Invalid parameters were supplied to Stripe's API
    rescue Stripe::AuthenticationError => e
      # Authentication with Stripe's API failed
      # (maybe you changed API keys recently)
    rescue Stripe::APIConnectionError => e
      # Network communication with Stripe failed
    rescue Stripe::StripeError => e
      # Display a very generic error to the user, and maybe send
      # yourself an email
      body = e.json_body
      err  = body[:error]
      puts "Status is: #{e.http_status}"
      puts "Type is: #{err[:type]}"
      puts "Code is: #{err[:code]}"
      # param is '' in this case
      puts "Param is: #{err[:param]}"
      puts "Message is: #{err[:message]}"
    end
  end

end