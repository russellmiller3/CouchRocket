# CouchRocket

CouchRocket is an e-commerce program to let users sell and buy new furniture.

Program running here: <a href="https://couchrocket.herokuapp.com/">couchrocket.herokuapp.com</a>

## Integrations:
* Stripe - Payment
* Twilio - SMS alerts
* Mailgun - Emails
* Filepicker - Uploading files
* <a href="https://wrapbootstrap.com/theme/unify-responsive-website-template-WB0412697">Unify Template</a>

## Functions:

Buyers can:
* Register / Login / Change Password / Reset Password
* Order an item (pre-auth via stripe) using Guest Checkout
* Upon receiving the item, accept (charged on stripe) and or reject (charged only shipping)


Sellers can:
* Register / Login / Change Password / Reset Password
* Guest Add Item, Login or Register afterwards
* Post an item
* Alerts(Flash) when item is added
* Enter their payment information to receive funds
* Get paid once a buyer has bought an item


Admin can:
* Enter Shipper Info
* Send shipper email to start the delivery process

## Running the Software:

1. Clone the repo
1. 'bundle install --without production'
1. 'cp .env.example .env'
		Fill in the .env settings with your values. Sign up for all of the services mentioned above to obtain their keys.
1. 'rake db:seed' to seed the database with three sample users:
	* admin (login: comicsguy@adamm.net / password: admin1) - has access to admin panel
	* Joe Seller (login: russell@adamm.net / password: song11)
	* Tom Buyer (login: ram@themillermediagroup.com / password: song11)
1. rake 'env:session_secret' - Sets a long, random string for the apps session secret.
1. 'rerun -c rackup'
1. Open it in your browser



