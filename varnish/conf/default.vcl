vcl 4.0;
import std;
import header;
import querystring;
import directors;


# Varnish load balancer configuration
#probe healthcheck {
#    .url = "/index.php";
#
#    .interval = 30s;
#    .timeout = 15s;
#    .window = 8;
#    .threshold = 3;
#    .initial = 3;
#    .expected_response = 200;
#}

backend default_one {
    .host = "web";
    .port = "80";
    .first_byte_timeout = 30s;
    .connect_timeout = 5s;
    .between_bytes_timeout = 2s;
}
backend admin {
    .host = "web";
    .port = "80";
    .first_byte_timeout = 6000s;
    .connect_timeout = 6000s;
    .between_bytes_timeout = 2s;
}


# Acls for allowing refresh from a browser
acl allow_refresh {
   "web";
}

# Acls for trust in
acl is_local {
   "127.0.0.1";
   "localhost";
}

# Admin detection. Used to find out when special backend to use for admin connections.
sub detect_admin {
    unset req.http.X-Admin-Match;

    if (req.url ~ "^(/index.php)?//admin/") {
        set req.http.X-Admin-Match = "1";
    }
}


 # Custom functions
sub normalize_url {
        #if (req.url ~ "(\?|&)(gclid|cx|ie|cof|siteurl|zanpid|origin|utm_[a-z]+|mr:[A-z]+|fb_local:[A-z]+)=") {
        # Some generic URL manipulation, useful for high hit ratio, e.g. removing all those track parameters
        #set req.url = querystring.regfilter(req.url, "gclid|cx|ie|cof|siteurl|zanpid|origin|utm_[a-z]+|mr:[A-z]+|fb_local:[A-z]+");
        #}
    
    # Strip a trailing ? if it exists
    if (req.url ~ "\?$") {
        set req.url = regsub(req.url, "\?$", "");
    } else {
        set req.url = std.querysort(req.url);
    }
}

sub normalize_gzip_ua {
    # Normalize Accept-Encoding header
    # straight from the manual: https://www.varnish-cache.org/docs/3.0/tutorial/vary.html
    if (req.http.Accept-Encoding) {
        if (req.url ~ "\.(jpg|png|gif|gz|tgz|bz2|tbz|mp3|ogg)$") {
            # No point in compressing these
            unset req.http.Accept-Encoding;
        } elsif (req.http.Accept-Encoding ~ "gzip") {
            set req.http.Accept-Encoding = "gzip";
        } elsif (req.http.Accept-Encoding ~ "deflate") {
            set req.http.Accept-Encoding = "deflate";
        } else {
            # unkown algorithm
            unset req.http.Accept-Encoding;
        }
    }

    if (req.http.User-Agent ~ "(?i)(ads|google|bing|msn|yandex|baidu|ro|career|)bot" ||
        req.http.User-Agent ~ "(?i)(baidu|jike|symantec)spider" ||
        req.http.User-Agent ~ "(?i)(facebook|scanner)" ||
        req.http.User-Agent ~ "(?i)(web)crawler") {
        set req.http.X-UA-Device = "bot";
    }

    set req.http.User-Agent = req.http.User-Agent + " " + req.http.X-UA-Device;
}

sub extract_cookie {
    set req.http.X-Cookie-Store = "";
    set req.http.X-Cookie-Currency = "";
    set req.http.X-Cookie-Segment = "";

    if (req.http.cookie ~ "(^|; ?)store=[^;]+") {
        set req.http.X-Cookie-Store = "store=" + regsub(req.http.cookie, "(^|.*; ?)store=([^;]+);?.*", "\2") + "; ";
    }

    if (req.http.cookie ~ "(^|; ?)store=[^;]+") {
        set req.http.X-Cookie-Currency = "store=" + regsub(req.http.cookie, "(^|.*; ?)store=([^;]+);?.*", "\2") + "; ";
    }

    if (req.http.cookie ~ "(^|; ?)segment_checksum=[^;]+") {
        set req.http.X-Cookie-Segment = "segment_checksum=" + regsub(req.http.cookie, "(^|.*; ?)segment_checksum=([^;]+);?.*", "\2") + "; ";
    }
}


sub normalize_customer_segment {
    unset req.http.X-Cache-Segment;

    if (req.http.cookie ~ "(^|; ?)segment_checksum=[^;]+;") {
        set req.http.X-Cache-Segment = regsub(req.http.cookie, "(^|.*; ?)segment_checksum=([^;]+);.*", "\2");
    }
}

# Various optimizations for esi component of the system
sub normalize_esi {
   # Send Surrogate-Capability headers to announce ESI support to backend
    set req.http.Surrogate-Capability = "key=ESI/1.0";
    unset req.http.X-Esi-Include;

    if (req.esi_level > 0) {
        # Notify Magento that we are performing ESI include call
        set req.http.X-Esi-Include = 1;

        # If in url we have an instruction to filter cookies in url
        if (req.url ~ "/filter_cookies/1/") {
            unset req.http.Cookie;
            set req.http.Cookie = req.http.X-Cookie-Store + req.http.X-Cookie-Currency + req.http.X-Cookie-Segment;
        }

        # If in url we have an instruction to exclude all cookies from url
        if (req.url ~ "/filter_referrer/1/") {
            unset req.http.Referer;
        }
    }
}

# Handle the HTTP request received by the client
sub vcl_recv {
    # shortcut for DFind requests
    if (req.url ~ "^/w00tw00t") {
        return (synth(404, "Not Found"));
    }

    call detect_admin;

    set client.identity = req.http.User-Agent + " " + client.ip;

    call normalize_url;
    call extract_cookie;
    call normalize_customer_segment;
    call normalize_gzip_ua;
    call normalize_esi;

    if (req.http.X-Forwarded-For) {
        set req.http.X-Forwarded-For = regsub(req.http.X-Forwarded-For, "^(^[^,]+),?.*$", "\1");
        if (std.ip(req.http.X-Forwarded-For, "127.0.0.1") == "127.0.0.1" ) {
            return (synth(400, "Bad request"));
        }

        if (client.ip !~ is_local) {
            unset req.http.X-Forwarded-For;
        }
    }


    call normalize_gzip_ua;
    call normalize_esi;

    if (req.http.X-Admin-Match) {
        set req.backend_hint = admin;
        unset req.http.X-Admin-Match;
        return (pass);
    } else {
        set req.backend_hint = default_one;
    }

    if (req.http.Ssl-Offloaded && client.ip !~ is_local) {
        unset req.http.Ssl-Offloaded;
    }

    if (req.restarts == 0) {
        if (client.ip !~ is_local) {
            set req.http.X-Forwarded-For = client.ip;
        }
    }

    set req.http.Host = regsub(req.http.Host, ":[0-9]+", "");

    if (req.http.Cache-Control ~ "no-cache"
        && client.ip ~ is_local
        && req.http.X-Forwarded-For        && std.ip(req.http.X-Forwarded-For, "127.0.0.1") ~ allow_refresh ) {
        set req.hash_always_miss = true;
    } else if (req.http.Cache-Control ~ "no-cache" && client.ip !~ is_local && client.ip ~ allow_refresh) {
        set req.hash_always_miss = true;
    }

    # Large static files should be piped, so they are delivered directly to the end-user without
    # waiting for Varnish to fully read the file first.
    if (req.url ~ "^[^?]*\.(mp[34]|rar|tar|tgz|gz|wav|zip|pdf|rtf|bz2|flv|png|jpeg|jpg|doc|bmp)(\?.*)?$") {
        return (pipe);
    }

    # Do not cache requests that are not cachable. Cache only GET, HEAD and OPTIONS
    if (req.method != "GET" && req.method != "HEAD" && req.method != "OPTIONS") {
        return (pass);
    }

    # Remove all cookies for static files that can be cached
    if (req.url ~ "^[^?]*\.(css|eot|svg|gif|ico|js|less|swf|txt|woff|xml|css\.map)(\?.*)?$") {
        unset req.http.Cookie;
    }

    # Only deal with "normal" types
    if (req.method != "GET" &&
        req.method != "HEAD" &&
        req.method != "PUT" &&
        req.method != "POST" &&
        req.method != "TRACE" &&
        req.method != "OPTIONS" &&
        req.method != "PATCH" &&
        req.method != "DELETE") {
        /* Non-RFC2616 or CONNECT which is weird. */
        return (pipe);
    }

    # Large static files should be piped, so they are delivered directly to the end-user without
    # waiting for Varnish to fully read the file first.
    if (req.url ~ "^[^?]*\.(mp[34]|rar|tar|tgz|gz|wav|zip|pdf|rtf|bz2|flv|doc|bmp)(\?.*)?$") {
        return (pipe);
    }

    # Do not cache requests that are not cachable. Cache only GET, HEAD and OPTIONS
    if (req.method != "GET" && req.method != "HEAD" && req.method != "OPTIONS") {
        return (pass);
    }

    # Remove all cookies for static files that can be cached
    if (req.url ~ "^[^?]*\.(css|eot|svg|gif|ico|js|jpg|jpeg|png|less|swf|txt|woff|xml|css\.map)(\?.*)?$") {
        unset req.http.Cookie;
    }

    set req.http.X-External-Gzip = 1;

    return (hash);
}

# The data on which the hashing will take place
sub vcl_hash {
    hash_data(req.url);

    if (req.http.host) {
        hash_data(req.http.host);
    } else {
        hash_data(server.ip);
    }

    
    if (req.http.Ssl-Offloaded) {
        hash_data(req.http.Ssl-Offloaded);
    }

    if (req.http.X-Requested-With) {
        hash_data(req.http.X-Requested-With);
    }

    if (req.http.X-Cache-Segment) {
        hash_data(req.http.X-Cache-Segment);
    }

    # Add authorization as cache key,
    # in order to make possible checking staging environments
    if (req.http.Authorization) {
        hash_data(req.http.Authorization);
    }

    set req.http.X-External-Gzip = 1;

    return (lookup);
}

# Unsets accept-encoding in order to process gzip by ourselves
sub vcl_backend_fetch {
    if (bereq.http.X-External-Gzip) {
        unset bereq.http.Accept-Encoding;
    }

    return (fetch);
}

# Handle the HTTP request coming from our backend
sub vcl_backend_response {
    # Parse ESI request and remove Surrogate-Control header
    # BRUTE FORCED THIS IN FOR DEV PURPOSES.
    #if (beresp.http.Surrogate-Control ~ "ESI/1.0") {
        set beresp.do_esi = true;
    #}

    # Enable gzip compression, if header for it is specified
    if (beresp.http.X-Cache-Gzip) {
        unset beresp.http.X-Cache-Gzip;
        set beresp.do_gzip = true;
    }

    # Sometimes, a 301 or 302 redirect formed via Apache's mod_rewrite can mess with the HTTP port that is being passed along.
    # This often happens with simple rewrite rules in a scenario where Varnish runs on :80 and Apache on :8080 on the same box.
    # A redirect can then often redirect the end-user to a URL on :8080, where it should be :80.
    # This may need finetuning on your setup.
    #
    # To prevent accidental replace, we only filter the 301/302 redirects for now.
    if (beresp.status == 301 || beresp.status == 302) {
        set beresp.http.Location = regsub(beresp.http.Location, ":[0-9]+", "");
        set beresp.uncacheable = true;
        set beresp.ttl = 30s;
        return (deliver);
    }

    # Make 404 page being cached for 30 seconds to prevent backend load
    if (beresp.status == 404) {
        set beresp.ttl = 30s;
        return (deliver);
    }

    # Hit-for-pass for auth and request erors for 5s
    if (beresp.status > 400 && beresp.status < 500) {
        set beresp.ttl = 5s;
        set beresp.uncacheable = true;
        return (deliver);
    }

    # Hit-for-pass auth for backend errors, without ttl and grace definition
    if (beresp.status >= 500 && beresp.status < 600) {
        set beresp.ttl = 0s;
        set beresp.grace = 0s;
        set beresp.uncacheable = true;
        return (deliver);
    }

    set beresp.http.X-UA-Device = bereq.http.X-UA-Device;

    if (!beresp.http.X-Cache-Segment) {
        set beresp.http.X-Cache-Segment = bereq.http.X-Cache-Segment;
    }

    # Cache all static files that are small by nature
    if (bereq.url ~ "^[^?]*\.(css|svg|eot|jpg|jpeg|png|gif|ico|js|less|txt|woff|xml|css\.map)(\?.*)?$") {
        set beresp.ttl = 5h;
        set beresp.grace = 5h;
        unset beresp.http.Set-Cookie;

        # Compress text based static files
        if (bereq.url ~ "^[^?]*\.(css|svg|js|less|txt|xml|css\.map)(\?.*)?$") {
            set beresp.do_gzip = true;
        }

        return (deliver);
    }

    if (beresp.http.X-Cache-Ttl) {
        set beresp.ttl = std.duration(beresp.http.X-Cache-Ttl, 0s);
        set beresp.grace = 5h;
        unset beresp.http.Set-Cookie;
    } else {
        set beresp.ttl = 5s;
        set beresp.uncacheable = true;
    }

    return (deliver);
}

# The routine when we deliver the HTTP request to the user
# Last chance to modify headers that are sent to the client
sub vcl_deliver {
    if (obj.hits > 0) {
        set resp.http.X-Cache = "cached";
    } else {
        set resp.http.X-Cache = "uncached";
    }

    header.remove(resp.http.Set-Cookie, "segment_checksum=;");
    header.remove(resp.http.Set-Cookie, "store=;");

    if (resp.http.X-Cache-Segment ~ "^.+$" && (!req.http.X-Cache-Segment || req.http.X-Cache-Segment != resp.http.X-Cache-Segment)
        && !header.get(resp.http.Set-Cookie, "segment_checksum=")) {
        header.append(resp.http.Set-Cookie, "segment_checksum=" + resp.http.X-Cache-Segment + "; Domain=." + resp.http.X-Cookie-Domain + "; Path=/");
    }

    if (resp.http.X-Cache-Store ~ "^.+$" && (!req.http.X-Cookie-Store || req.http.X-Cookie-Store != resp.http.X-Cache-Store)
        && !header.get(resp.http.Set-Cookie, "store=")) {
        header.append(resp.http.Set-Cookie, "store=" + resp.http.X-Cache-Store + "; Domain=." + resp.http.X-Cookie-Domain + "; Path=/; HttpOnly");
    }

    # Remove debug headers if ip address is not whitelisted
    if (client.ip ~ is_local && std.ip(req.http.X-Forwarded-For, "127.0.0.1") !~ allow_refresh) {
        unset resp.http.X-Debug;
        unset resp.http.X-Varnish;
    }

    # Remove headers that should be removed when there is no debug enabled
    if (!resp.http.X-Debug) {
        unset resp.http.X-UA-Device;
        unset resp.http.X-Cache-Segment;
        unset resp.http.X-Cache-Objects;
        unset resp.http.X-Cache-Store;
        unset resp.http.X-Cache-Ttl;
        unset resp.http.Ssl-Offloaded;
        unset resp.http.X-Powered-By;
        unset resp.http.Server;
        unset resp.http.Via;
        unset resp.http.Link;
    }

    return (deliver);
}