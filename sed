<script language="JavaScript">
  var q = location.href;
  if (q.search(/\/manpages\/.*\/man[0-9]\/.*[^0-9]\.html$/) >= 0) {
    // Current location matches a legacy link, with just a plain .html filename
    // Try to redirect to the new location, which has a .[0-9].html filename
    location.replace(q.replace(/\/man([0-9])\/(.*)\.html/, "/man$1/$2.$1.html"));
  } else {
    // Try redirecting to a page of search results
    q = q.replace(/.*\//, "");
    q = q.replace(/\.html$/, "");
    location.replace('/cgi-bin/search.py?cx=003883529982892832976%3A5zl6o8w6f0s&cof=FORID%3A9&ie=UTF-8&titles=404&lr=lang_en&q=' + q);
  }
</script>

<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Transitional//EN"
    "http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd">
<html xmlns="http://www.w3.org/1999/xhtml" xml:lang="en" lang="en" dir="ltr">
    <head profile="http://a9.com/-/spec/opensearch/1.1/">
        <meta http-equiv="Content-Type" content="text/html; charset=UTF-8">
        <link rel="search"
            type="application/opensearchdescription+xml"
            href="/ubuntu-manpage-search.xml"
            title="Ubuntu Manpage Search" />
        <title>Ubuntu Manpage:

Not Found
</title>
        <link rel="stylesheet" type="text/css" href="/assets/light/css/reset.css"/>
        <link rel="stylesheet" type="text/css" href="/assets/light/css/styles.css"/>
        <link rel="stylesheet" type="text/css" href="/manpages.css"/>
        <link rel="shortcut icon" href="/assets/light/images/favicon.ico" type="image/x-icon" />
        <script language="JavaScript" src="/functions.js"></script>
    </head>
    <body>
        <div id="container">
            <div id="container-inner">
                <div id="header">
                    <h1 id="ubuntu-header"><a href="/">Ubuntu manuals</a></h1>
                </div>
                <div id="subheader">
                    <div id="subheader-search">
                        <form method="get" action="/cgi-bin/search.py" id="cse-search-box">
                            <input type="text" name="q" tabindex="1" id="search-box-input" />
                            <button type="submit" name="op" id="search-box-button"><span>go</span></button>
                            <input type="hidden" name="cx" value="003883529982892832976:5zl6o8w6f0s" />
                            <input type="hidden" name="cof" value="FORID:9" />
                            <input type="hidden" name="ie" value="UTF-8" />
                            <script type="text/javascript" src="http://www.google.com/coop/cse/brand?form=cse-search-box&lang=en"></script>
                        </form>
                    </div>
                    <div class="subheader-menu">
                        <script>navbar();</script>
                    </div>
                </div>
                <div id="content" class="clearfix content-area">
                    <div class="level-4-nav" id="toc"></div>
                    <script>distroAndSection();</script>

<br><big><big><strong>We could not find that page</strong></big></big><br><br>
We will try to redirect you to some related material.

                </div>
            </div>
            <div id="copyright">
                <p>
                Powered by the <a href="https://launchpad.net/ubuntu-manpage-repository">Ubuntu Manpage Repository</a> generator
                maintained by <a href="http://blog.dustinkirkland.com/">Dustin Kirkland</a><br />
                &copy; 2010 Canonical Ltd. Ubuntu and Canonical are registered trademarks of Canonical Ltd.
                </p>
            </div>
        </div>
    </body>
</html>

