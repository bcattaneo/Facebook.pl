#!/usr/bin/perl -w

use strict;
require "./facebook.pl";

my $user = "MyFacebookEMAIL"; # you can use alias too.
my $password = "MyPassword";

# Login example
unless (eval {fblogin("$user", "$password");}) {
	print "Error: $@";
}

# Wall post example
if (fbcheck()) {
	# Optional: fbwall("Hello world!", "FriendID");
	unless (eval {fbwall("Hello world!");}) {
		print "Error: $@";
	}
}
else {
	die "Not logged in\n";
}
#EOF
