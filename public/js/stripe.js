  <script type="text/javascript" src="https://js.stripe.com/v2/"></script>

	<script type="text/javascript">
  // This identifies your website in the createToken call below
  Stripe.setPublishableKey('pk_test_zf9EXVq1RKyMFqX8Pv8xab9V');


	jQuery(function($) {
	  $('#payment-form').submit(function(event) {
	    var $form = $(this);

	    // Disable the submit button to prevent repeated clicks
	    $form.find('button').prop('disabled', true);

	    Stripe.card.createToken($form, stripeResponseHandler);

	    // Prevent the form from submitting with the default action
	    return false;
	  });
	});

	function stripeResponseHandler(status, response) {
	  var $form = $('#payment-form');

	  if (response.error) {
	    // Show the errors on the form
	    $form.find('.payment-errors').text(response.error.message);
	    $form.find('button').prop('disabled', false);
	  } else {
	    // response contains id and card, which contains additional card details
	    var token = response.id;
	    var customer = customer.id;
	    // Insert the token and customer into the form so they gets submitted to my server
	    $form.append($('<input type="hidden" name="stripeToken" />').val(token));

	    $form.append($('<input type="hidden" name="stripeCustomerID" />').val(customer));



	    // and submit
	    $form.get(0).submit();
	  }
	};

  </script>