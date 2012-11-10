#!/usr/bin/perl -w

use strict;
require "./facebook.pl";

my $user = 'MyFacebookEMAIL'; # you can use alias too.
my $password = 'MyPassword';

# Login example
unless (eval {fblogin("$user", "$password");}) {
	chop $@;
	print "Error: $@\n";
}
else {
	print "Logged in.\n";
}

# Login check
if (fbcheck()) {
	# Wall post example
	# Usage: fbwall("Hello world!", "FriendID (optional)");
	unless (eval {fbwall("Hello world!");}) {
		chop $@;
		print "Error: $@\n";
	}
	else {
		print "Message sent.\n";
	}
	# Composer wall post example
	# Usage: fbcomposer("Page title", "http://www.MyCoolWebPage.com", "Description text", "http://www.MyCoolWebPage.com/logo.jpg (optional)", "My post message (optional)", "FriendID (optional)", "http://www.MyCoolWebPage.com/favicon.ico (optional)");
	unless (eval {fbcomposer("Page title", "http://www.MyCoolWebPage.com", "Description text", "http://www.MyCoolWebPage.com/logo.jpg", "My post message");}) {
		chop $@;
		print "Error: $@\n";
	}
	else {
		print "Composer message sent.\n";
	}
}
else {
	die "Not logged in.\n";
}
#EOF
