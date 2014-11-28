require_relative './config/dotenv'
require_relative './models'

namespace :db do
	rake :drop

	task :seed do

		joe = User.create({
			:id=>"1",
			:name=>"Joe Seller"
			})

		joe.SellerProfile.create

		couch = Item.create({
				:type=>"Couch",
				:brand=>"Davis",
				:notes=>"A fine leather couch suitable for all occasions",
				:original_price=>"10000",
				:asking_price=>"7000",
				:picture1_url=>"http://www.thisthatandlife.com/wp-content/uploads/2012/11/Craigslist-Man-Leather-Couch-225.jpg",:user_id=>"1",:buyer_id=>"2"
				:user_id=>"1"
			})

		joe.save
		item.save

	end

end
