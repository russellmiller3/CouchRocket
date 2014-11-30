require_relative './config/dotenv'
require_relative './models'

namespace :db do

	task :reset do
		:drop
		:create
	end

	task :seed do

			joe = User.create({
				:id=>"1",
				:name=>"Joe Seller"
				})

			joe_sellerprofile = SellerProfile.create({
				:id=>"1",
				:user_id => "1"
				})

			couch = Item.create({
					:id =>"1",
					:type=>"Couch",
					:brand=>"Davis",
					:notes=>"A fine leather couch suitable for all occasions",
					:original_price=>"10000",
					:asking_price=>"7000",
					:picture1_url=>"http://www.thisthatandlife.com/wp-content/uploads/2012/11/Craigslist-Man-Leather-Couch-225.jpg",
					:seller_profile_id=>"1"
				})

			joe.save
			couch.save
			joe_sellerprofile.save
	end

	task :ready_to_test => [:reset, :seed] do
    puts "Old Database destroyed & New Database seeded."
  end

end