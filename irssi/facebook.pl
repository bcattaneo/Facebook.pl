#
# Usage:
#	/FBLOGIN
#	/FBWALL [-msg "<message>"] [-friend <FriendID> (optional)]
#	/FBCOMPOSER [-title "<title>"] [-url <http://myweb.com>] [-desc "<My description>"] [-img <http://myweb.com/image.jpg> (optional)] [-msg "<message>" (optional)] [-friend <FriendID> (optional)] [-fav <http://myweb.com/favicon.ico> (optional)]
# Settings:
#	/SET facebook_autologin [on/off]
#	/SET facebook_user [email/username]
#	/SET facebook_pass [password]
#	/SET facebook_agent [custom User-Agent] (default is Firefox)
# Notes:
#	"<br>", "\n", and "%0A" are line breaks
#	Some options like "-msg" needs quotes for using spaces
# Examples:
#	/FBWALL -msg "Hey dude, I am using Irssi right now :D" -friend 100004386815625
#	/FBCOMPOSER -title "Irssi, The client of the future" -url http://www.irssi.org -desc "Irssi official Website" -img http://www.irssi.org/images/irssitop.png -msg "Install Irssi :D"
#

use strict;
use IO::Socket;
use Encode;
use Getopt::Long;
use vars qw($VERSION %IRSSI);

use Irssi;
$VERSION = "1.21";
%IRSSI = (
	authors => 'sud0',
	contact => 'sud0@unitedhack.com',
	name => "facebook",
	description => 'This is a simple irssi script that tries to collect functions for using Facebook without Graph API.',
	license => "Public Domain",
	url => "http://github.com/mafiasud0/Facebook.pl/tree/master/irssi",
	changed => "2012-11-09",
	changes => "See ChangeLog",
);

Irssi::theme_register([
	'facebook_inicio', '%B::%n %_Facebook.pl%_ -- Configuration: %_/set facebook%_',
	'facebook_fbwall', '%B::%n %_Facebook.pl%_ -- Usage: %_/fbwall -msg "My message" -friend FriendID (optional)%_',
	'facebook_fbcomposer', '%B::%n %_Facebook.pl%_ -- Usage: %_/fbwall -title "Web title" -url http://mycoolweb.com -desc "My cool description" -img http://mycoolweb.com/image.jpg (optional) -msg "My message" (optional) -friend FriendID (optional) -favicon http://mycoolweb.com/favicon.ico (optional)%_',
	'facebook_fblogin', '%B::%n %_Facebook.pl%_ -- Not logged in. Log in using: %_/fblogin%_',
	'facebook_sent', '%B::%n %_Facebook.pl%_ -- Message sent.',
	'facebook_csent', '%B::%n %_Facebook.pl%_ -- Composer message sent.',
	'facebook_msgerror', '%B::%n %_Facebook.pl%_ -- %RError:%n $0',
	'facebook_logged', '%B::%n %_Facebook.pl%_ -- Logged in.',
	'facebook_user', '%B::%n %_Facebook.pl%_ -- Username/password unspecified. Please see: %_/set facebook%_',
]);

Irssi::settings_add_bool("misc", "facebook_autologin", 0);
Irssi::settings_add_str("misc", "facebook_user", '');
Irssi::settings_add_str("misc", "facebook_pass", '');
Irssi::settings_add_str("misc", "facebook_agent", 'Mozilla/5.0 (Windows NT 5.1; rv:16.0) Gecko/20100101 Firefox/16.0');

my $autologin = Irssi::settings_get_bool("facebook_autologin");
my $user = Irssi::settings_get_str("facebook_user");
my $password = Irssi::settings_get_str("facebook_pass");
my $agent = Irssi::settings_get_str("facebook_agent");

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
				die "Connection error.\n";
			}
			$sock->autoflush(1);
			print $sock "GET $url HTTP/1.1" . $EOL;
			print $sock "Host: www.facebook.com" . $EOL;
			print $sock "User-Agent: $agent" . $EOL;
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
		die "URL/cookie/body unspecified.\n";
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
			die "Connection error.\n";
		}
		$sock->autoflush(1);
		print $sock "POST $url HTTP/1.1" . $EOL;
		print $sock "Host: www.facebook.com" . $EOL;
		print $sock "User-Agent: $agent" . $EOL;
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
		die "URL/cookie/cuerpo unspecified.\n";
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
			die "$@.\n";
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
				die "$@.\n";
			}
			if ($cookies =~ /c_user=(.*?)\;/o) {
				$c_user = $1;
			}
			else {
				fbclose();
				die "Unexpected error.\n";
			}
			if ($datos =~ /name=\"fb_dtsg\" value=\"(.*?)\"/o) {
				$fb_dtsg = $1;
			}
			else {
				fbclose();
				die "Unexpected error.\n";
			}
			if ($datos =~ /name=\"xhpc_targetid\" value=\"(.*?)\"/o) {
				$xhpc_targetid = $1;
			}
			else {
				fbclose();
				die "Unexpected error.\n";
			}
			if ($datos =~ /name=\"xhpc_composerid\" value=\"(.*?)\"/o) {
				$xhpc_composerid = $1;
			}
			else {
				fbclose();
				die "Unexpected error.\n";
			}
			return 1;
		}
		else {
			# Facebook says: Nope!
			die "Wrong username/password.\n";
		}
	}
	else {
		die "Username/password unspecified.\n";
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
				die "$@.\n";
			}
			
		}
		else {
			unless(eval {$datos = fbpost("/ajax/updatestatus.php", "$cookies", "fb_dtsg=$fb_dtsg&xhpc_targetid=$xhpc_targetid&xhpc_context=home&xhpc_ismeta=1&xhpc_fbx=1&xhpc_timeline=&xhpc_composerid=$xhpc_composerid&xhpc_message_text=$mensaje&xhpc_message=$mensaje&is_explicit_place=&composertags_place=&composertags_place_name=&composer_session_id=&composertags_city=&disable_location_sharing=false&composer_predicted_city=&audience[0][value]=80&nctr[_mod]=pagelet_composer&__user=$c_user&__a=1");}) {
				fbclose();
				chop $@;
				die "$@.\n";
			}
		}
		if ($datos =~ /errorSummary/) {
			die "Failed to publish message.\n";
		}
		return 1;
	}
	else {
		die "Cookies/message unspecified.\n";
	}
}

sub fbcomposer {
	my $title = shift;
	my $url = shift;
	my $description = shift;
	my $image = shift;
	my $mensaje = shift;
	my $target = shift;
	my $favicon = shift;
	if (defined($cookies) && defined($title) && defined($url) && defined($description) && $title ne "" && $url ne "" && $description ne "") {
		# $xhpc_targetid (actual)
		# Can be a friend/page too.
		my $datos;
		if (defined($mensaje) && $mensaje ne "") {
			$mensaje =~ s/\\n/\%0A/g;
			$mensaje =~ s/<br>/\%0A/g;
		}
		else {
			$mensaje = "";
		}
		if (not defined($image)) {
			$image = "";
		}
		if (not defined($favicon)) {
			$favicon = "";
		}
		if (defined($target) && $target ne "") {
			unless(eval {$datos = fbpost("/ajax/profile/composer.php", "$cookies", "fb_dtsg=$fb_dtsg&xhpc_composerid=$xhpc_composerid&xhpc_targetid=$target&xhpc_context=profile&xhpc_fbx=&xhpc_timeline=1&xhpc_ismeta=1&xhpc_message_text=$mensaje&xhpc_message=$mensaje&aktion=post&app_id=2309869772&UIThumbPager_Input=0&attachment[params][metaTagMap][0][http-equiv]=content-type&attachment[params][metaTagMap][0][content]=text%2Fhtml%3B%20charset%3Dutf-8&attachment[params][metaTagMap][1][content]=$description&attachment[params][metaTagMap][1][name]=description&attachment[params][metaTagMap][2][content]=noodp&attachment[params][metaTagMap][2][name]=robots&attachment[params][metaTagMap][3][itemprop]=image&attachment[params][metaTagMap][3][content]=&attachment[params][medium]=106&attachment[params][urlInfo][canonical]=$url&attachment[params][urlInfo][final]=$url&attachment[params][urlInfo][user]=$url&attachment[params][favicon]=$favicon&attachment[params][title]=$title&attachment[params][fragment_title]=&attachment[params][external_author]=&attachment[params][summary]=$description&attachment[params][url]=$url&attachment[params][error]=1&attachment[params][og_info][guesses][0][0]=og%3Aurl&attachment[params][og_info][guesses][0][1]=$url&attachment[params][og_info][guesses][1][0]=og%3Atitle&attachment[params][og_info][guesses][1][1]=$title&attachment[params][og_info][guesses][2][0]=og%3Adescription&attachment[params][og_info][guesses][2][1]=$description&attachment[params][og_info][guesses][3][0]=og%3Aimage&attachment[params][og_info][guesses][3][1]=$image&attachment[params][responseCode]=200&attachment[params][redirectPath][0][status]=301&attachment[params][redirectPath][0][url]=$url&attachment[params][redirectPath][0][ip]=&attachment[params][metaTags][description]=$description&attachment[params][metaTags][robots]=noodp&attachment[params][images][0]=$image&attachment[params][cache_hit]=1&attachment[params][global_share_id]=&attachment[type]=100&composertags_place=&composertags_place_name=&composer_session_id=&is_explicit_place=&backdated_date[year]=&backdated_date[month]=&backdated_date[day]=&backdated_date[hour]=&backdated_date[minute]=&scheduled=0&UITargetedPrivacyWidget=80&nctr[_mod]=pagelet_timeline_recent&__user=$c_user&__a=1");}) {
				fbclose();
				chop $@;
				die "$@.\n";
			}
			
		}
		else {
			unless(eval {$datos = fbpost("/ajax/profile/composer.php", "$cookies", "fb_dtsg=$fb_dtsg&xhpc_composerid=$xhpc_composerid&xhpc_targetid=$xhpc_targetid&xhpc_context=profile&xhpc_fbx=&xhpc_timeline=1&xhpc_ismeta=1&xhpc_message_text=$mensaje&xhpc_message=$mensaje&aktion=post&app_id=2309869772&UIThumbPager_Input=0&attachment[params][metaTagMap][0][http-equiv]=content-type&attachment[params][metaTagMap][0][content]=text%2Fhtml%3B%20charset%3Dutf-8&attachment[params][metaTagMap][1][content]=$description&attachment[params][metaTagMap][1][name]=description&attachment[params][metaTagMap][2][content]=noodp&attachment[params][metaTagMap][2][name]=robots&attachment[params][metaTagMap][3][itemprop]=image&attachment[params][metaTagMap][3][content]=&attachment[params][medium]=106&attachment[params][urlInfo][canonical]=$url&attachment[params][urlInfo][final]=$url&attachment[params][urlInfo][user]=$url&attachment[params][favicon]=$favicon&attachment[params][title]=$title&attachment[params][fragment_title]=&attachment[params][external_author]=&attachment[params][summary]=$description&attachment[params][url]=$url&attachment[params][error]=1&attachment[params][og_info][guesses][0][0]=og%3Aurl&attachment[params][og_info][guesses][0][1]=$url&attachment[params][og_info][guesses][1][0]=og%3Atitle&attachment[params][og_info][guesses][1][1]=$title&attachment[params][og_info][guesses][2][0]=og%3Adescription&attachment[params][og_info][guesses][2][1]=$description&attachment[params][og_info][guesses][3][0]=og%3Aimage&attachment[params][og_info][guesses][3][1]=$image&attachment[params][responseCode]=200&attachment[params][redirectPath][0][status]=301&attachment[params][redirectPath][0][url]=$url&attachment[params][redirectPath][0][ip]=&attachment[params][metaTags][description]=$description&attachment[params][metaTags][robots]=noodp&attachment[params][images][0]=$image&attachment[params][cache_hit]=1&attachment[params][global_share_id]=&attachment[type]=100&composertags_place=&composertags_place_name=&composer_session_id=&is_explicit_place=&backdated_date[year]=&backdated_date[month]=&backdated_date[day]=&backdated_date[hour]=&backdated_date[minute]=&scheduled=0&UITargetedPrivacyWidget=80&nctr[_mod]=pagelet_timeline_recent&__user=$c_user&__a=1");}) {
				fbclose();
				chop $@;
				die "$@.\n";
			}
		}
		if ($datos =~ /errorSummary/ || $datos =~ /ServersideRedirect/) {
			die "Failed to publish composer message.\n";
		}
		return 1;
	}
	else {
		die "Cookies/title/url/description unspecified.\n";
	}
}
# Facebook.pl EOF

my @loop;

sub quotes {
	my @return;
	my $switch = 0;
	my $value = "";
	foreach (@loop) {
		my $param = $_;
		if ($param =~ /\"/ && $param !~ /\"(.*)\"/) {
			if ($switch == 0) {
				$switch = 1;
				if ($value eq "") {
					$value = "$param";
				}
				else {
					$value = "$value $param";
				}
			}
			else {
				$switch = 0;
				if ($value eq "") {
					$value = "$param";
				}
				else {
					$value = "$value $param";
				}
				$value =~ s/\"//g;
				push(@return, $value);
				$value = "";
			}
		}
		else {
			if ($switch == 1) {
				if ($value eq "") {
					$value = "$param";
				}
				else {
					$value = "$value $param";
				}
			}
			else {
				push(@return, $param);
			}
		}
	}
	if ($value ne "") {
		$value =~ s/\"//g;
		push(@return, $value);
		$value = "";
	}
	return @return;
}

sub login {
	$user = Irssi::settings_get_str("facebook_user");
	$password = Irssi::settings_get_str("facebook_pass");
	if (defined($user) && defined($password) && $user ne "" && $password ne "") {
		# fblogin
		unless (eval {fblogin("$user", "$password");}) {
			chop $@;
			Irssi::printformat(MSGLEVEL_CLIENTCRAP, 'facebook_msgerror', "$@");
		}
		else {
			Irssi::printformat(MSGLEVEL_CLIENTCRAP, 'facebook_logged');
		}
	}
	else {
		Irssi::printformat(MSGLEVEL_CLIENTCRAP, 'facebook_user');
	}
}
sub wall {
	my ($msg, $server, $witem) = @_;
	my ($fbmsg, $fbfriend);
	Getopt::Long::config('permute', 'no_ignore_case');
	@loop = split(/\s/, $msg);
	local(@ARGV) = quotes();
	GetOptions (
		'msg:s' => \$fbmsg,
		'friend:s' => \$fbfriend,
	);
	if (defined($fbmsg) && $fbmsg ne "") {
		# fbwall
		if (fbcheck()) {
			unless (eval {fbwall("$fbmsg", "$fbfriend");}) {
				chop $@;
				Irssi::printformat(MSGLEVEL_CLIENTCRAP, 'facebook_msgerror', "$@");
			}
			else {
				Irssi::printformat(MSGLEVEL_CLIENTCRAP, 'facebook_sent');
			}
		}
		else {
			Irssi::printformat(MSGLEVEL_CLIENTCRAP, 'facebook_fblogin');
		}
	}
	else {
		Irssi::printformat(MSGLEVEL_CLIENTCRAP, 'facebook_fbwall');
	}
}

sub composer {
	my ($msg, $server, $witem) = @_;
	my ($fbtitle, $fburl, $fbdesc, $fbimage, $fbmsg, $fbfriend, $fbfavicon);
	Getopt::Long::config('permute', 'no_ignore_case');
	@loop = split(/\s/, $msg);
	local(@ARGV) = quotes();
	GetOptions (
		'title:s' => \$fbtitle,
		'url|web:s' => \$fburl,
		'desc|description:s' => \$fbdesc,
		'img|image:s' => \$fbimage,
		'msg:s' => \$fbmsg,
		'friend:s' => \$fbfriend,
		'fav|favicon:s' => \$fbfavicon,
	);
	if (defined($fbtitle) && defined($fburl) && defined($fbdesc) && $fbtitle ne "" && $fburl ne "" && $fbdesc ne "") {
		# fbcomposer
		if (fbcheck()) {
			unless (eval {fbcomposer("$fbtitle", "$fburl", "$fbdesc", "$fbimage", "$fbmsg", "$fbfriend", "$fbfavicon");}) {
				chop $@;
				Irssi::printformat(MSGLEVEL_CLIENTCRAP, 'facebook_msgerror', "$@");
			}
			else {
				Irssi::printformat(MSGLEVEL_CLIENTCRAP, 'facebook_csent');
			}
		}
		else {
			Irssi::printformat(MSGLEVEL_CLIENTCRAP, 'facebook_fblogin');
		}
	}
	else {
		Irssi::printformat(MSGLEVEL_CLIENTCRAP, 'facebook_fbcomposer');
	}
}

Irssi::command_bind("fblogin", "login");
Irssi::command_bind("fbwall", "wall");
Irssi::command_bind("fbcomposer", "composer");

Irssi::printformat(MSGLEVEL_CLIENTCRAP, 'facebook_inicio');

if ($autologin == 1) {
	login();
}
#EOF
