#!/usr/bin/perl -w

#
# Facebook.pl (1.21)
#
# Description:
# This is a simple perl script that
# tries to collect functions for using
# Facebook without Graph API.
#
# History:
# See ChangeLog.
#
# License:
# Public Domain.
#
# sud0 <sud0@unitedhack.com>
# http://sud0.unitedhack.com
# http://github.com/mafiasud0
#

use strict;
use IO::Socket;
use Encode;

# Cookies
my $cookies;

# fbwall
my $fb_dtsg;
my $xhpc_targetid;
my $xhpc_composerid;
my $c_user;

# http
my $agent = "Mozilla/5.0 (Windows NT 5.1; rv:16.0) Gecko/20100101 Firefox/16.0"; # Firefox
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
	my $host = shift;
	my $alive = shift;
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
			if (defined($host) && $host ne "") {
				print $sock "Host: $host" . $EOL;
			}
			else {
				print $sock "Host: www.facebook.com" . $EOL;
			}
			print $sock "User-Agent: $agent" . $EOL;
			print $sock "Accept: text/html,application/xhtml+xml,application/xml,application/ecmascript,text/javascript,text/jscript;q=0.9,*/*;q=0.8" . $EOL;
			print $sock "Accept-Language: en-us,en;q=0.5" . $EOL;
			print $sock "Accept-Encoding: deflate" . $EOL;
			print $sock "Accept-Charset: UTF-8;q=0.7,*;q=0.7" . $EOL;
			if ($cookie ne "") {
				print $sock "Cookie: $cookie" . $EOL;
			}
			if (defined($alive) && $alive == 1) {
				print $sock "Connection: keep-alive" . $BLANK;
			}
			else {
				print $sock "Connection: close" . $BLANK;
			}
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
	my $host = shift;
	my $alive = shift;
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
		if (defined($host) && $host ne "") {
			print $sock "Host: $host" . $EOL;
		}
		else {
			print $sock "Host: www.facebook.com" . $EOL;
		}
		print $sock "User-Agent: $agent" . $EOL;
		print $sock "Content-Length: ".$cuerpo =~ s/(.)/$1/sg."" . $EOL;
		print $sock "Content-Type: application/x-www-form-urlencoded" . $EOL;
		if ($cookie ne "") {
			print $sock "Cookie: $cookie" . $EOL;
		}
		if (defined($alive) && $alive == 1) {
			print $sock "Connection: keep-alive" . $BLANK;
		}
		else {
			print $sock "Connection: close" . $BLANK;
		}
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
#EOF
