# CouchRocket is an e-commerce program to let users sell and buy new furniture.

## Integrations:
Stripe - Payment
Twilio - SMS alerts
Mailgun - Emails
Filepicker - Uploading files

## Functions:
Buyers can:
Register (to come)
Order an item (pre-auth via stripe)
Upon receiving the item, accept (and pay) or reject (pay only shipping)

Sellers can:
Register
Post an item
Enter their payment information to receive funds
Get paid once a buyer has bought an item

Admin can:
Enter Shipper Info
Send shipper email to start the delivery process

## Running the Software:

1. Clone the repo
1. 'bundle install --without production'
1. 'cp .env.example .env'
		Fill in the .env settings with your values. Sign up for all of the services mentioned above to obtain their keys.
1. 'rake db:reset'
1. 'rerun -c rackup'
1. Open it in your browser



