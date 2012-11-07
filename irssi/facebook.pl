#
# Usage:
#	/FBLOGIN
#	/FBWALL [message]
# Settings:
#	/SET facebook_autologin [on/off]
#	/SET facebook_user [email or username]
#	/SET facebook_pass [password]
# Notes:
#	"<br>", "\n", and "%0A" are line breaks
#

use strict;
use IO::Socket;
use Encode;
use vars qw($VERSION %IRSSI);

use Irssi;
$VERSION = "1.00";
%IRSSI = (
	authors => 'sud0',
	contact => 'sud0@unitedhack.com',
	name => "facebook",
	description => 'This is a simple irssi script that tries to collect functions for using Facebook without Graph API.',
	license => "Public Domain",
	url => "http://github.com/mafiasud0/Facebook.pl/tree/master/irssi",
	changed => "2012-11-07",
	changes => "See ChangeLog",
);

Irssi::settings_add_bool("misc", "facebook_autologin", 0);
Irssi::settings_add_str("misc", "facebook_user", '');
Irssi::settings_add_str("misc", "facebook_pass", '');

my $autologin = Irssi::settings_get_bool("facebook_autologin");
my $user = Irssi::settings_get_str("facebook_user");
my $password = Irssi::settings_get_str("facebook_pass");

# Facebook.pl
# Cookies
my $cookies;

# fbwall
my $fb_dtsg;
my $xhpc_targetid;
my $xhpc_composerid;
my $c_user;

# http
my $EOL = "\015\012";
my $BLANK = $EOL x 2;

sub fbclose {
	undef($cookies);
	undef($fb_dtsg);
	undef($xhpc_targetid);
	undef($xhpc_composerid);
	undef($c_user);
}

sub fbcheck {
	if (defined($cookies)) {
		return 1;
	}
	else {
		return 0;
	}
}

sub fbget {
	my $url = shift;
	my $cookie = shift;
	if (defined($url) && defined($cookie) && $url ne "") {
		# Loop
		while (1) {
			my $datos;
			my $sock = IO::Socket::INET->new(PeerAddr =>"www.facebook.com", PeerPort =>"http(80)", Proto => "tcp");
			unless ($sock) {
				fbclose();
				die "Connection error\n";
			}
			$sock->autoflush(1);
			print $sock "GET $url HTTP/1.1" . $EOL;
			print $sock "Host: www.facebook.com" . $EOL;
			print $sock "User-Agent: Mozilla/5.0 (Macintosh; U; Intel Mac OS X 10.5; en-US; rv:1.9.1b3pre) Gecko/20081130 Minefield/3.1b3pre" . $EOL;
			print $sock "Accept: text/html,application/xhtml+xml,application/xml,application/ecmascript,text/javascript,text/jscript;q=0.9,*/*;q=0.8" . $EOL;
			print $sock "Accept-Language: en-us,en;q=0.5" . $EOL;
			print $sock "Accept-Encoding: deflate" . $EOL;
			print $sock "Accept-Charset: UTF-8;q=0.7,*;q=0.7" . $EOL;
			if ($cookie ne "") {
				print $sock "Cookie: $cookie" . $EOL;
			}
			print $sock "Connection: close" . $BLANK;
			while (<$sock>) {
				$datos = "$datos$_";
			}
			if ($datos =~ /Location: (.*?)$EOL/o) {
				$url = $1;
				close $sock;
				# Back to loop
			}
			else {
				close $sock;
				# Decode it for your own needs.
				#$datos = decode("utf-8", $datos);
				return "$datos";
			}
		}
	}
	else {
		die "URL/cookie/body unspecified\n";
	}
}

sub fbpost {
	my $url = shift;
	my $cookie = shift;
	my $cuerpo = shift;
	if (defined($url) && defined($cookie) && defined($cuerpo) && $url ne "" && $cuerpo ne "") {
		# HTTP POST
		my $datos;
		$cuerpo = encode("utf-8", $cuerpo);
		my $sock = IO::Socket::INET->new(PeerAddr =>"www.facebook.com", PeerPort =>"http(80)", Proto => "tcp");
		unless ($sock) {
			fbclose();
			die "Connection error\n";
		}
		$sock->autoflush(1);
		print $sock "POST $url HTTP/1.1" . $EOL;
		print $sock "Host: www.facebook.com" . $EOL;
		print $sock "User-Agent: Mozilla/5.0 (Macintosh; U; Intel Mac OS X 10.5; en-US; rv:1.9.1b3pre) Gecko/20081130 Minefield/3.1b3pre" . $EOL;
		print $sock "Content-Length: ".$cuerpo =~ s/(.)/$1/sg."" . $EOL;
		print $sock "Content-Type: application/x-www-form-urlencoded" . $EOL;
		if ($cookie ne "") {
			print $sock "Cookie: $cookie" . $EOL;
		}
		print $sock "Connection: close" . $BLANK;
		print $sock "$cuerpo" . $EOL;
		while (<$sock>) {
			$datos = "$datos$_";
		}
		close $sock;
		return $datos;
	}
	else {
		die "URL/cookie/cuerpo unspecified\n";
	}
}

sub fblogin {
	my $email = shift;
	my $pass = shift;
	if (defined($email) && defined($pass) && $email ne "" && $pass ne "") {
		fbclose();
		my $datos;
		unless (eval {$datos = fbpost("/login.php?login_attempt=1", "reg_fb_gate=http%3A%2F%2Fwww.facebook.com%2Flogin.php%3Flogin_attempt%3D1; reg_fb_ref=http%3A%2F%2Fwww.facebook.com%2Flogin.php%3Flogin_attempt%3D1", "email=$email&pass=$pass");}) {
			fbclose();
			chop $@;
			die "$@\n";
		}
		if ($datos =~ /302 Found/) {
			# We're in
			# Getting cookies...
			for (split /$EOL/, $datos) {
				my $cookie1 = $_;
				$cookie1 =~ s/\s+$//;
				if ($cookie1 =~ /Set-Cookie: (.*)/) {
					my $cookie2 = $1;
					if ($cookie2 !~ /deleted/) {
						my @cookie3 = split(" ", $cookie2);
						if (defined($cookies)) {
							$cookies = "$cookies $cookie3[0]";
						}
						else {
							$cookies = "$cookie3[0]";
						}
					}
				}
			}
			$cookies =~ s/\;+$//g;
			unless (eval {$datos = fbget("/", "$cookies");}) {
				fbclose();
				chop $@;
				die "$@\n";
			}
			if ($cookies =~ /c_user=(.*?)\;/o) {
				$c_user = $1;
			}
			else {
				fbclose();
				die "Unexpected error\n";
			}
			if ($datos =~ /name=\"fb_dtsg\" value=\"(.*?)\"/o) {
				$fb_dtsg = $1;
			}
			else {
				fbclose();
				die "Unexpected error\n";
			}
			if ($datos =~ /name=\"xhpc_targetid\" value=\"(.*?)\"/o) {
				$xhpc_targetid = $1;
			}
			else {
				fbclose();
				die "Unexpected error\n";
			}
			if ($datos =~ /name=\"xhpc_composerid\" value=\"(.*?)\"/o) {
				$xhpc_composerid = $1;
			}
			else {
				fbclose();
				die "Unexpected error\n";
			}
			return 1;
		}
		else {
			# Facebook says: Nope!
			die "Wrong username/password\n";
		}
	}
	else {
		die "Username/password unspecified\n";
	}
}

sub fbwall {
	my $mensaje = shift;
	my $target = shift;
	if (defined($cookies) && defined($mensaje) && $mensaje ne "") {
		# $xhpc_targetid (actual)
		# Can be a friend/page too.
		my $datos;
		$mensaje =~ s/\\n/\%0A/g;
		$mensaje =~ s/<br>/\%0A/g;
		if (defined($target) && $target ne "") {
			unless(eval {$datos = fbpost("/ajax/updatestatus.php", "$cookies", "fb_dtsg=$fb_dtsg&xhpc_targetid=$target&xhpc_context=home&xhpc_ismeta=1&xhpc_fbx=1&xhpc_timeline=&xhpc_composerid=$xhpc_composerid&xhpc_message_text=$mensaje&xhpc_message=$mensaje&is_explicit_place=&composertags_place=&composertags_place_name=&composer_session_id=&composertags_city=&disable_location_sharing=false&composer_predicted_city=&audience[0][value]=80&nctr[_mod]=pagelet_composer&__user=$c_user&__a=1");}) {
				fbclose();
				chop $@;
				die "$@\n";
			}
			
		}
		else {
			unless(eval {$datos = fbpost("/ajax/updatestatus.php", "$cookies", "fb_dtsg=$fb_dtsg&xhpc_targetid=$xhpc_targetid&xhpc_context=home&xhpc_ismeta=1&xhpc_fbx=1&xhpc_timeline=&xhpc_composerid=$xhpc_composerid&xhpc_message_text=$mensaje&xhpc_message=$mensaje&is_explicit_place=&composertags_place=&composertags_place_name=&composer_session_id=&composertags_city=&disable_location_sharing=false&composer_predicted_city=&audience[0][value]=80&nctr[_mod]=pagelet_composer&__user=$c_user&__a=1");}) {
				fbclose();
				chop $@;
				die "$@\n";
			}Irssi::settings_add_bool("misc", "facebook_autologin", 0);
Irssi::settings_add_str("misc", "facebook_user", '');
Irssi::settings_add_str("misc", "facebook_pass", '');
		}
		if ($datos =~ /errorSummary/) {
			die "Failed to publish message\n";
		}
		return 1;
	}
	else {
		die "Cookies/message unspecified\n";
	}
}
# Facebook.pl EOF

sub login {
	$user = Irssi::settings_get_str("facebook_user");
	$password = Irssi::settings_get_str("facebook_pass");
	if (defined($user) && defined($password) && $user ne "" && $password ne "") {
		# fblogin
		unless (eval {fblogin("$user", "$password");}) {
			chop $@;
			Irssi::print("Facebook.pl -- Error: $@.");
		}
		else {
			Irssi::print("Facebook.pl -- Logged in.");
		}
	}
	else {
		Irssi::print("Facebook.pl -- Username/password unspecified. Please see: /set facebook_");
	}
}

sub wall {
	my ($msg, $server, $witem) = @_;
	if (defined($msg) && $msg ne "") {
		# Wall post example
		if (fbcheck()) {
			# Optional: fbwall("Hello world!", "FriendID");
			unless (eval {fbwall("$msg");}) {
				Irssi::print("Facebook.pl -- Error: $@.");
			}
			else {
				Irssi::print("Facebook.pl -- Message sent.");
			}
		}
		else {
			Irssi::print("Facebook.pl -- Not logged. Log in using: /fblogin");
		}
	}
	else {
		Irssi::print("Facebook.pl -- Usage: /fbwall [message]");
	}
}

Irssi::command_bind("fblogin", "login");
Irssi::command_bind("fbwall", "wall");

Irssi::print("Facebook.pl -- Configuration: /set facebook_");

if ($autologin == 1) {
	login();
}
#EOF
