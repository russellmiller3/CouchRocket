require 'data_mapper'

DataMapper.setup(:default, ENV['DATABASE_URL'])

class User
	include DataMapper::Resource

	property :id, Serial
	property :name, String
	property :email, String
	property :phone, String
	property :address, Text

	has 1, :seller_profile
	has 1, :buyer_profile

end

class SellerProfile
	include DataMapper::Resource

	belongs_to :user, :key => true

	has n, :items, { :child_key => [:user_id] }


end

class Item
	include DataMapper::Resource

	belongs_to :seller_profile, :key => true
	belongs_to :buyer_profile, :required => false

	property :id, Serial
	property :type, Text
	property :brand, Text
	property :notes, Text
	property :original_price, Integer
	property :asking_price, Integer
	property :picture1_url, Text
	property :picture2_url, Text
	property :picture3_url, Text
	property :sold, Boolean, :default  => false
	property :delivery_notes, Text

end



class BuyerProfile
	include DataMapper::Resource

	belongs_to :user, :key => true

	has n, :items, { :child_key => [:user_id] }

end


class OrderDetails
	include DataMapper::Resource

	property :created_at, Date
	property :price, Integer
	property :fulfilled, Boolean, :default => false
	property :shipdate, Date
	property :charged, Boolean, :default => false
	property :stripe_token, String
	property :stripe_customer_id, String

	belongs_to :item, :key => true

end


DataMapper.finalize
DataMapper.auto_upgrade!


