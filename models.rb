require 'data_mapper'

DataMapper.setup(:default, ENV['DATABASE_URL'])

class User
	include DataMapper::Resource

	property :id, Serial
	property :name, String
	has n, :items, { :child_key => [:user_id] }

end


class Item
	include DataMapper::Resource

	property :id, Serial
	property :type, Text
	property :brand, Text
	property :notes, Text
	property :original_price, Float
	property :asking_price, Float
	property :picture1_url, Text
	property :picture2_url, Text
	property :picture3_url, Text
	property :sold, Boolean, :default  => false
	property :delivery_notes, Text

	belongs_to :user
	belongs_to :buyer

end

class Buyer
	include DataMapper::Resource

	property :id, Serial
	property :name, String
	property :email, String
	property :phone, String
	property :address, Text
	property :stripe_token, String
	property :stripe_customer_id, String

	has n, :items, { :child_key => [:buyer_id] }

end

DataMapper.finalize
DataMapper.auto_upgrade!

user = User.new(:id=>"1",:name=>"joe")
user.save
buyer = Buyer.new(:id=>"2",:name=>"dummy_buyer")
buyer.save
item = Item.new(:id=>"3",:type=>"Couch",:brand=>"Davis",
	:notes=>"A fine leather couch suitable for all occasions",
	:original_price=>"100",:asking_price=>"70",
	:picture1_url=>"http://www.thisthatandlife.com/wp-content/uploads/2012/11/Craigslist-Man-Leather-Couch-225.jpg",:user_id=>"1",:buyer_id=>"2"
	)
item.save
